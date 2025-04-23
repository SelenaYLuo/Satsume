// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error Snowball_InsufficientFund();
error Snowball_Expired();
error NoFundsToDistribute();
error InvalidConfig(); 
error TransferFail();
error NotApproved();
event SnowballCreated(uint256 snowballId);

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISnowballWorkingCapital {
    function deleteAllSnowballRequests(uint256 snowballID) external;
}

interface ILoanFactory {
    function Loans(uint256) external view returns (uint256, uint256, uint256, address);
    function burnToken(uint256 tokenID) external;
    function UpdateLoanAmount(uint256 loanID, uint256 subtractAmount) external;
}

contract Snowball {
    // Type Declarations

    /* Contract Variables */
    struct snowballContract {
        uint256 id;
        uint256 maxSlots;
        uint256 price;
        uint256 duration;
        uint256 totalDebt;
        address payable owner;
        uint256 startTime;
        uint256 numParticipants;
        uint256 balance;
        mapping(uint256 => mapping(address => uint256)) cohorts_tickets;
        mapping(uint256 => address[]) cohorts;
        uint256[] cohortTicketAmounts;
        uint256[] cohortPrices;
        uint256[] payouts;
        uint256[] thresholds;
    }
    
    /* Snowball State Variables */
    uint256 public ID = 0; 
    uint256 public constant MINIMUM_PRICE = 5 * 10 ** 6;
    uint256 public constant MINIMUM_DURATION = 900; 
    uint256 public commission = 25; // basis points (divided by 10,000)
    uint256 public failedTransferBalance;
    address payable public bank;
    address public owner; 
    address public s_forwarderAddress; 
    address public WCProviderAddress; 
    uint256[] public activeSnowballContractsByID;
    mapping(uint256 => snowballContract) public s_idToSnowball;
    mapping (uint256 => uint256[]) public snowballIDToLoanIDPerTranche; //The loan IDs for the i-indexed loan tranche are in i-th index of the array. 
    mapping (address => uint256[]) public addressToSnowballIDs;

    


    /* State Variables */
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    uint64 private immutable i_subscriptionId;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;
    bytes32 private immutable i_gasLane;
    ISnowballWorkingCapital public snowballWorkingCapital; 
    ILoanFactory public loanFactory; 
    IERC20 public usdcToken; // Declare the USDC token contract
    

    constructor(address _usdcToken) {
        owner = msg.sender; // Set the owner to the contract deployer
        bank = payable(owner);
        usdcToken = IERC20(_usdcToken); // Initialize the USDC token contract
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NotOwner");
        _;
    }

    function setBank(address payable newBank) external onlyOwner {
        bank = payable(newBank);
    }

    function createSnowball(
        uint256 _maxSlots,
        uint256 _price,
        uint256 _duration,
        uint256[] memory _payouts,
        uint256[] memory _thresholds
    ) public payable returns (uint256) {
        // Ensure the lengths of the pay and thresholds arrays are equal


        if (_payouts.length != _thresholds.length || _payouts.length < 1 || _payouts.length > 5 || _thresholds[0] <=1 || _thresholds[_thresholds.length - 1]> _maxSlots || _duration <= MINIMUM_DURATION) {
            revert InvalidConfig(); 
        }

        // Ensure the sum of the payouts is less than the price. Cannot be combined with price gap logic due to potential underflow. 
        // Also check that payouts of zero are prohibited
        uint256 sumPayouts = 0;
        uint256[] memory pay = new uint256[](_payouts.length);
        for (uint256 i = 0; i < _payouts.length; i++) {
            sumPayouts += _payouts[i];
            pay[i] = _payouts[i];
            console.log("_payouts[i]:", _payouts[i]);
            console.log("pay[i]:", pay[i]);
            if(pay[i] == 0) {
                revert InvalidConfig();
            }
        }

        if(sumPayouts > _price) {
            revert InvalidConfig(); 
        }

        // Ensure the difference between the price and the sum of payouts is greater than the minimum price
        if(_price - sumPayouts < MINIMUM_PRICE) {
            revert InvalidConfig(); 
        }

        // Ensure the values in the thresholds array are unique and increasing
        for (uint256 i = 1; i < _thresholds.length; i++) {
            if(_thresholds[i] < _thresholds[i - 1]) {
                revert InvalidConfig(); 
            }
        }

        uint256[] memory _cohortPrices = new uint256[](_payouts.length + 1);

        // Get the possible prices paid for each cohort
        _cohortPrices[0] = _price; 
        for (uint256 i = 1; i < _cohortPrices.length; i++) {
            _cohortPrices[i] = _cohortPrices[i-1] - pay[i-1]; 
        }

        // Initialize a new snowball contract and store it in storage
        snowballContract storage newSnowball = s_idToSnowball[ID];
        newSnowball.id = ID;
        newSnowball.maxSlots = _maxSlots;
        newSnowball.price = _price;
        newSnowball.duration = _duration;
        newSnowball.payouts = pay;
        newSnowball.thresholds = _thresholds;
        newSnowball.owner = payable(msg.sender);
        newSnowball.startTime = block.timestamp;
        newSnowball.numParticipants = 0;
        newSnowball.balance = 0;
        newSnowball.cohortPrices = _cohortPrices;
        newSnowball.totalDebt = 0; 

        // Initialize cohortTicketAmounts with zeros
        uint256[] memory _cohortTicketAmounts = new uint256[](_cohortPrices.length);
        for (uint256 i = 0; i < _cohortTicketAmounts.length; i++) {
            _cohortTicketAmounts[i] = 0;
        }
        newSnowball.cohortTicketAmounts = _cohortTicketAmounts;

        activeSnowballContractsByID.push(ID); 
        addressToSnowballIDs[msg.sender].push(ID);
        emit SnowballCreated(ID);
        ID += 1; 
        return ID;
    }


    function getSnowball(
        uint256 snowballID
    )
        public
        view
        returns (
            uint256 maxSlots,
            uint256 price,
            uint256 duration,
            uint256[] memory payouts,
            uint256[] memory thresholds,
            address snowballOwner, 
            uint256 startTime,
            uint256 balance,
            uint256 numParticipants,
            uint256[] memory cohortPrices
        )
    {
        snowballContract storage snowball = s_idToSnowball[snowballID];
        return (
            snowball.maxSlots,
            snowball.price,
            snowball.duration,
            snowball.payouts,
            snowball.thresholds,
            snowball.owner,
            snowball.startTime,
            snowball.balance,
            snowball.numParticipants,
            snowball.cohortPrices
        );
    }

    // Additional function to get cohort data if needed
    function getCohortData(uint256 snowballID, uint256 key) public view returns (address[] memory) {
        return (s_idToSnowball[snowballID].cohorts[key]);
    }

    function joinContract(uint256 snowballID, uint256 tickets) public  {
        // Load necessary variables from storage to memory for gas efficiency
        uint256 numParticipants = s_idToSnowball[snowballID].numParticipants;
        uint256[] memory thresholds = s_idToSnowball[snowballID].thresholds;
        uint256 price = s_idToSnowball[snowballID].price;
        uint256[] memory cohortPrices = s_idToSnowball[snowballID].cohortPrices;

        // Check if the contract is still valid
        if (block.timestamp - s_idToSnowball[snowballID].duration > s_idToSnowball[snowballID].startTime || numParticipants == s_idToSnowball[snowballID].maxSlots) {
            revert Snowball_Expired();
        }

        //Find the updated prices and tickets possible
        //uint256 maxTotalTickets = Math.min(s_idToSnowball[snowballID].maxSlots, numParticipants + tickets);
        uint256 additionalTickets = (Math.min(s_idToSnowball[snowballID].maxSlots - numParticipants, tickets)); 
        uint256 cohort;
        for (cohort = 0; cohort < thresholds.length; cohort++) {
            if (thresholds[cohort] > (numParticipants + additionalTickets)) {
                break;
            }
        }
        price = cohortPrices[cohort];

        //Update Snowball State
        if (s_idToSnowball[snowballID].price != price) {
            s_idToSnowball[snowballID].price = price;
        }
        s_idToSnowball[snowballID].numParticipants += additionalTickets;
        s_idToSnowball[snowballID].balance += additionalTickets * (price - cohortPrices[cohortPrices.length - 1]);


        // Add the purchaser to the cohorts mapping
        if (s_idToSnowball[snowballID].cohorts_tickets[cohort][msg.sender] == 0) {
            s_idToSnowball[snowballID].cohorts_tickets[cohort][msg.sender] += additionalTickets;
            s_idToSnowball[snowballID].cohorts[cohort].push(msg.sender);
            s_idToSnowball[snowballID].cohortTicketAmounts[cohort] += additionalTickets;
        } else {
            s_idToSnowball[snowballID].cohorts_tickets[cohort][msg.sender] += additionalTickets;
            s_idToSnowball[snowballID].cohortTicketAmounts[cohort] += additionalTickets;
        }

        // Calculate the commissions and transfer to bank
        uint256 remainingAmount = additionalTickets * cohortPrices[cohortPrices.length - 1]; //Amount available for snowball owner and debt holders. Not in custody
        console.log(remainingAmount);
        uint256 commissionAmount = calculateCommission(remainingAmount);
        console.log(commissionAmount);
        remainingAmount -= commissionAmount;
        console.log(remainingAmount);
        bool success = usdcToken.transferFrom(msg.sender, bank,  commissionAmount);
        if (!success) {
            console.log("f1");
            revert TransferFail();
        }
        success = usdcToken.transferFrom(msg.sender, address(this), (additionalTickets * (price - cohortPrices[cohortPrices.length - 1])));
        if (!success) {
            console.log("f1");
            revert TransferFail();
        }

        // Pay the debt holders if any
        if (s_idToSnowball[snowballID].totalDebt > 0) {
            remainingAmount = payDebtHolders(snowballID, remainingAmount);
            console.log("Remaining %s", remainingAmount);

            // Pay any remaining amount to the snowball owner
            success = usdcToken.transferFrom(msg.sender, s_idToSnowball[snowballID].owner, remainingAmount);
            if (!success) {
                revert TransferFail();
            }
        } else {
            // Pay snowball owner directly
            success = usdcToken.transferFrom(msg.sender, s_idToSnowball[snowballID].owner, remainingAmount);
            if (!success) {
                revert TransferFail();
            }
        }
    }

    //Calculates the commissions given the non-custody amount
    function calculateCommission(uint256 totalAmount) internal view returns (uint256) { //should be internal
        uint256 commissionAmount = totalAmount /10000 *commission; 
        return (commissionAmount);
    }

    //This function pays any debt holders for a given snowball after receiving the post-commissions available Amount. Function returns any residual amounts. 
    function payDebtHolders(uint256 snowballID, uint256 availableAmount) private returns (uint256 remainingAmount) {
        uint256 totalDebt = s_idToSnowball[snowballID].totalDebt;
        uint256[] memory listOfTrancheLoans = getLoansbySnowballID(snowballID);
        console.log("Initial totalDebt:", totalDebt);
        console.log("Initial availableAmount:", availableAmount);

        // Initiate helper variables
        uint256 closedTranches = 0; 
        uint256[] memory amountsToPay = new uint256[](listOfTrancheLoans.length);
        address[] memory ownersToPay = new address[](listOfTrancheLoans.length);
        uint256 numPayments = 0;

        // Update total debt 
        if (totalDebt < availableAmount) {
            s_idToSnowball[snowballID].totalDebt = 0;
        } else {
            s_idToSnowball[snowballID].totalDebt = totalDebt - availableAmount; 
        }

        console.log("Updated totalDebt:", s_idToSnowball[snowballID].totalDebt);

        // Calculate payment amounts for each tranche and load state changes into memory
        for (uint256 i = 0; i < listOfTrancheLoans.length; i++) {
            (uint256 faceAmount, , ,address debtOwner) = loanFactory.Loans(listOfTrancheLoans[i]);
            console.log("Processing tranche", i);

            // Check the number of tranches for which we can make full payment. 
            if (faceAmount <= availableAmount) {
                // Load repayment data into memory
                amountsToPay[numPayments] = faceAmount;
                ownersToPay[numPayments] = debtOwner;
                numPayments++;
                closedTranches++; 

                // Update the remaining amount 
                availableAmount -= faceAmount;

                // Burn the associated tokens
                loanFactory.burnToken(listOfTrancheLoans[i]);
                console.log("Full payment for tranche", i);

            // Calculate the payment amount for tranches and load state changes into memory for tranches that we can do partial payment
            } else {
                if (availableAmount > 0) {
                    amountsToPay[numPayments] = availableAmount;
                    ownersToPay[numPayments] = debtOwner;
                    numPayments++;

                    // Update the tranche debt and remaining amount
                    loanFactory.UpdateLoanAmount(listOfTrancheLoans[i], availableAmount);
                    availableAmount = 0;
                    console.log("Partial payment for tranche", i);
                    break; 
                }
            }
        }

        // Shift and clean up closed tranches
        if (closedTranches > 0) {
            console.log("Cleaning up closed tranches");
            uint256 newLength = listOfTrancheLoans.length - closedTranches;
            if (newLength == 0) {
                // All tranches are closed, reset arrays
                snowballIDToLoanIDPerTranche[snowballID] = new uint256[](0);
            } else {
                for (uint256 i = 0; i < newLength; i++) {
                    snowballIDToLoanIDPerTranche[snowballID][i] = snowballIDToLoanIDPerTranche[snowballID][i + closedTranches];
                }
                for (uint256 i = 0; i < closedTranches; i++) { 
                    snowballIDToLoanIDPerTranche[snowballID].pop(); 
                }
            }
        }

        // Transfer payments
        for (uint256 i = 0; i < numPayments; i++) {
            if (amountsToPay[i] ==0) break;
            (bool success) = usdcToken.transferFrom(msg.sender, ownersToPay[i], amountsToPay[i]);
            if (!success) {
                failedTransferBalance += amountsToPay[i];
            }
            console.log("Paid debt holder", ownersToPay[i]);
            console.log("Paid:", amountsToPay[i]);
        }

        return availableAmount; // Return any leftover amount after paying debt holders
    }

    function checkUpkeep() public {
        uint256 closeCounter;
        uint256 updateCounter;
        bool upkeepNeeded = false;
        
        // Loop to check for contracts that need closing or updating
        for (uint256 i = 0; i < activeSnowballContractsByID.length; i++) {
            //Loading variables into memory
            uint256[] memory cohortPrices = s_idToSnowball[activeSnowballContractsByID[i]].cohortPrices;
            
            // Check if the contract is expired or full
            if (block.timestamp - s_idToSnowball[activeSnowballContractsByID[i]].duration >= s_idToSnowball[activeSnowballContractsByID[i]].startTime || s_idToSnowball[activeSnowballContractsByID[i]].numParticipants == s_idToSnowball[activeSnowballContractsByID[i]].maxSlots) {
                closeCounter += 1;
                upkeepNeeded = true;
                console.log("ID %s close.", s_idToSnowball[activeSnowballContractsByID[i]].id);
            } else {
                // Loop through each cohort
                for (uint256 j = 0; j < cohortPrices.length; j++) {
                    // Check if the effective prices paid for any cohorts are outdated and there are actual participants
                    if (cohortPrices[j] > s_idToSnowball[activeSnowballContractsByID[i]].price && s_idToSnowball[activeSnowballContractsByID[i]].cohorts[j].length > 0) {
                        updateCounter += 1;
                        upkeepNeeded = true;
                        console.log("ID %s update", s_idToSnowball[activeSnowballContractsByID[i]].id);
                        break; // no need to continue looping for this snowball
                    }
                }
            }
        }

        // Initialize arrays of upkeeps
        uint256[] memory toClose = new uint256[](closeCounter);
        uint256 closeIndex;
        uint256[] memory toUpdate = new uint256[](updateCounter);
        uint256 updateIndex;

        // Loop again to fill the arrays
        for (uint256 i = 0; i < activeSnowballContractsByID.length; i++) {

            //Loading variables into memory
            uint256[] memory cohortPrices = s_idToSnowball[activeSnowballContractsByID[i]].cohortPrices;
            
            if (block.timestamp - s_idToSnowball[activeSnowballContractsByID[i]].duration >= s_idToSnowball[activeSnowballContractsByID[i]].startTime 
            || s_idToSnowball[activeSnowballContractsByID[i]].numParticipants == s_idToSnowball[activeSnowballContractsByID[i]].maxSlots) {
                //toClose[closeIndex] = activeSnowballContractsByID[i];
                toClose[closeIndex] = i; 
                closeIndex += 1;
                console.log("Adding Snowball ID %s to close list.", s_idToSnowball[activeSnowballContractsByID[i]].id);
            } else {
                for (uint256 j = 0; j < cohortPrices.length; j++) {
                    if (cohortPrices[j] > s_idToSnowball[activeSnowballContractsByID[i]].price && s_idToSnowball[activeSnowballContractsByID[i]].cohorts[j].length > 0) {
                        toUpdate[updateIndex] = i;//activeSnowballContractsByID[i];
                        updateIndex += 1;
                        console.log("Adding Snowball ID %s to update list.", s_idToSnowball[activeSnowballContractsByID[i]].id);
                        break; // no need to continue looping for this snowball
                    }
                }
            }
        }

        // Encode the data to be passed to performUpkeep
        bytes memory performData = abi.encode(toClose, toUpdate);
        performUpkeep(performData);
        //return (upkeepNeeded, performData);
    }

    function performUpkeep(bytes memory performData) public {
        if(msg.sender != s_forwarderAddress) {
            revert NotApproved(); 
        }
        
        (uint256[] memory toClose, uint256[] memory toUpdate) = abi.decode(
            performData,
            (uint256[], uint256[])
        );
        
        // First pay cohorts then close contracts
        for (uint256 i = 0; i < toUpdate.length; i++) {
            uint256 snowballID = activeSnowballContractsByID[toUpdate[i]];
            console.log("Updating Snowball ID %s.", snowballID);
            uint256 accumulatedPayout = payoutCohorts(snowballID);
            console.log(accumulatedPayout);
            console.log(s_idToSnowball[snowballID].balance);
            s_idToSnowball[snowballID].balance -= accumulatedPayout;
        }

        // Close contracts
        uint256 i = toClose.length;
        while (i > 0) {
            i--;
            uint256 snowballID = activeSnowballContractsByID[toClose[i]];
            console.log("Closing Snowball ID %s.", snowballID);

            //snowballContract storage snowball = s_idToSnowball[snowballID];
            
            //Change below logic if not using USDC or other token vulnerable to re-entrancy. 
            uint256 accumulatedPayout = payoutCohorts(snowballID);
            console.log(accumulatedPayout);
            uint256 remainingAmount = s_idToSnowball[snowballID].balance - accumulatedPayout;
            console.log(s_idToSnowball[snowballID].balance);

            uint256 commissionAmount = calculateCommission(remainingAmount);
            console.log(commissionAmount);
            (bool success) = usdcToken.transfer(bank, commissionAmount);
            console.log(success);
            if(!success) {
                failedTransferBalance += commissionAmount;
            }
            remainingAmount -= commissionAmount; 
            s_idToSnowball[snowballID].balance = 0;
            
            if (s_idToSnowball[snowballID].totalDebt > 0) {
            remainingAmount = payDebtHolders(snowballID, remainingAmount);
            }
            console.log(1);
            
            if (remainingAmount > 0) {
                (bool success) = usdcToken.transfer(s_idToSnowball[snowballID].owner, remainingAmount);//snowball.owner.call{value: remainingAmount}("");
                if(!success) {
                    failedTransferBalance += remainingAmount;
                }
                console.log("Paid %s to owner.", remainingAmount);
            } 
            console.log(2);

            snowballWorkingCapital.deleteAllSnowballRequests(snowballID);
            console.log(3);

            activeSnowballContractsByID[toClose[i]] = activeSnowballContractsByID[activeSnowballContractsByID.length - 1];
            activeSnowballContractsByID.pop();
            console.log("Closed ", snowballID);
        }
    }

    function payoutCohorts(uint256 snowballID) private returns (uint256 accumulatedPayout) {
        //Load variables into memory
        uint256[] memory cohortPrices = s_idToSnowball[snowballID].cohortPrices;
        uint256 price = s_idToSnowball[snowballID].price;

        uint256 j = 0;
        while (j < cohortPrices.length && cohortPrices[j] > price) {
            address[] memory currentCohort = s_idToSnowball[snowballID].cohorts[j];
            uint256 currentCohortPrice = cohortPrices[j];
            s_idToSnowball[snowballID].cohortPrices[j] = price;
            for (uint256 k = 0; k < currentCohort.length; k++) {
                address user = currentCohort[k];
                uint256 tickets = s_idToSnowball[snowballID].cohorts_tickets[j][user];
                uint256 val = tickets * (currentCohortPrice - price);
                console.log(val);
                accumulatedPayout += val;
                //console.log(accumulatedPayout);
                console.log(usdcToken.balanceOf(address(this)));
                
                (bool success) = usdcToken.transfer(user, val); //payable(user).call{value: val}("");
                console.log(success);
                if(!success) {
                    console.log("f");
                    failedTransferBalance += val;
                }
            }
            j++;
        }
        return accumulatedPayout;
    }

    /// @notice Set the address that `performUpkeep` is called from
    /// @dev Only callable by the owner
    /// @param forwarderAddress the address to set
    //MAKE THIS ONLY OWNER
    function setForwarderAddress(address forwarderAddress) external onlyOwner {
        s_forwarderAddress = forwarderAddress;
    }

    function setWorkingCapitalProvider(address _WCProviderAddress) external onlyOwner {
        WCProviderAddress = _WCProviderAddress; 
        snowballWorkingCapital = ISnowballWorkingCapital(_WCProviderAddress); 
    }

    function setLoanFactory(address _loanFactoryAddress) external onlyOwner {
        loanFactory = ILoanFactory(_loanFactoryAddress); 
    }

    function getSnowballsByOwner(address user) public view returns (uint256[] memory) {
        return addressToSnowballIDs[user];
    }

    //Add debt to snowball in the next tranche and returns the tranche number. 
    function addDebtToSnowball(uint256 snowballID, uint256 debtAmount, uint256 loanID) external  returns (uint256) {
        if(msg.sender != WCProviderAddress) {
            revert NotApproved(); 
        }
        console.log(s_idToSnowball[snowballID].totalDebt);
        s_idToSnowball[snowballID].totalDebt += debtAmount;
        console.log(s_idToSnowball[snowballID].totalDebt);
        snowballIDToLoanIDPerTranche[snowballID].push(loanID);
        return snowballIDToLoanIDPerTranche[snowballID].length;
    }

    function getLoansbySnowballID(uint256 snowballID) public view returns (uint256[] memory) {
        return snowballIDToLoanIDPerTranche[snowballID];
    }

    // function sendFailedFunds (address to, uint256 amount) onlyOwner public {
    //     if (amount > failedTransferBalance) {
    //         revert TransferFail(); 
    //     }
    //     failedTransferBalance -= amount; 
    //     usdcToken.transfer(to, amount);
    // }


    function getSnowballMetrics(uint256 id) 
        external 
        view 
        returns(
            uint256, 
            uint256,
            uint256, 
            uint256, 
            address, 
            uint256, 
            uint256, 
            uint256, 
            uint256[] memory,
            uint256[] memory, 
            uint256[] memory
        ) 
    {
        snowballContract storage snowball = s_idToSnowball[id]; 
        return (
            snowball.price, 
            snowball.maxSlots,
            snowball.duration, 
            snowball.totalDebt, 
            snowball.owner, 
            snowball.startTime, 
            snowball.numParticipants, 
            snowball.balance, 
            snowball.cohortTicketAmounts,
            snowball.cohortPrices, 
            snowball.thresholds
        );
    }
}
