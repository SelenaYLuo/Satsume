// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error Snowball_InsufficientFund();
// error Snowball_Expired();
// error NoFundsToDistribute();
// error InvalidConfig(); 
// error TransferFail();
// error NotApproved();
// event SnowballCreated(uint256 snowballId);

// import "hardhat/console.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// interface ISnowballWorkingCapital {
//     function Loans(uint256 _loanID) external view returns (
//         address owner,
//         address debtor,
//         uint256 remainingAmount,
//         uint256 redeemableAmount
//     );
//     function repayDebt(uint256 _loanID, uint256 repaymentAmount) external;
// }

// interface ILoanFactory {
//     function Loans(uint256) external view returns (uint256, uint256, uint256, address);
//     function burnToken(uint256 tokenID) external;
//     function UpdateLoanAmount(uint256 loanID, uint256 subtractAmount) external;
// }

// contract Snowballv5 {
//     // Type Declarations
//     struct Snowball {
//         uint256 maxSlots; 
//         uint256 duration;
//         uint256 startTime;
//         uint256 numParticipants;
//         uint256[] thresholds;
//         uint256[] cohortPrices; 
//         uint256 custodyBalance; 
//         address owner; 
//         bool returnedCustody; 
//     }

//     struct Drawing {
//         uint256 maxSlots;
//         uint256 duration;
//         uint256 startTime;
//         uint256 numParticipants; 
//         uint256 price;
//         uint256 cohortSize;
//         uint256 rebateAmount;
//         uint256 custodyBalance; 
//         address owner; 
//         bool returnedCustody; 
//     }

//     struct Receipt {
//         uint256 snowballID;
//         uint256 effectivePricePaid; 
//         uint256 tickets; 
//         address owner; 
//     }


    
//     /* Snowball State Variables */
//     uint256 public snowballIDs = 1; 
//     uint256 public receiptIDs = 1;
//     uint256 public constant MINIMUM_PRICE = 5 * 10 ** 6;
//     uint256 public constant MINIMUM_DURATION = 900; 
//     uint256 public commission = 25; // basis points (divided by 10,000)
//     address payable public bank;
//     address public owner; 
//     address public s_forwarderAddress; 
//     address public WCProviderAddress; 
//     uint256[] public activeSnowballContractsByID;
//     mapping(uint256 => uint256) public IDtoContractType; 
//     mapping(uint256 => Snowball) public Snowballs;
//     mapping(uint256 => Drawing) public Drawings;
//     mapping(uint256 => Receipt) public Receipts;
//     mapping (address => uint256[]) public addressToSnowballIDs;
//     mapping (address => uint256[]) public addressToReceiptIDs;
//     mapping(address => uint256) public userTotalDebt; 
//     mapping(address => uint256[]) public userOutstandingLoans; 
//     mapping(address => uint256) public redeemableRewards; 

    


//     /* State Variables */
//     VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    
//     uint16 private constant REQUEST_CONFIRMATIONS = 3;
//     uint32 private immutable i_callbackGasLimit;
//     uint32 private constant NUM_WORDS = 1;
//     uint64 private immutable i_subscriptionId;
//     uint256 private s_lastTimeStamp;
//     uint256 private immutable i_interval;
//     bytes32 private immutable i_gasLane;
//     ISnowballWorkingCapital public snowballWorkingCapital; 
//     ILoanFactory public loanFactory; 
//     IERC20 public usdcToken; // Declare the USDC token contract
    

//     constructor(address _usdcToken) {
//         owner = msg.sender; // Set the owner to the contract deployer
//         bank = payable(owner);
//         usdcToken = IERC20(_usdcToken); // Initialize the USDC token contract
//     }

//     modifier onlyOwner() {
//         require(msg.sender == owner, "NotOwner");
//         _;
//     }

//     function setBank(address payable newBank) external onlyOwner {
//         bank = payable(newBank);
//     }

//     function createSnowball(
//         uint256 _maxSlots,
//         uint256 _duration,
//         uint256[] memory _cohortPrices,
//         uint256[] memory _thresholds
//     ) public returns(uint256) {
//         if (_cohortPrices.length -1 != _thresholds.length || _cohortPrices.length < 1 || _cohortPrices.length > 5 || 
//         _thresholds[0] <=1 || _thresholds[_thresholds.length - 1]> _maxSlots || _duration <= MINIMUM_DURATION ||
//         _cohortPrices[_cohortPrices.length-1] <MINIMUM_PRICE) {
//             revert InvalidConfig(); 
//         }
//         // Check that _cohortPrices is strictly decreasing and _thresholds is strictly increasing
//         for (uint256 i = 0; i < _thresholds.length; i++) {
//             if (_cohortPrices[i] <= _cohortPrices[i + 1]) {
//                 revert InvalidConfig();
//             }
//             if (i > 0 && _thresholds[i] <= _thresholds[i - 1]) {
//                 revert InvalidConfig();
//             }
//         }

//         // Initialize a new snowball contract and store it in storage
//         Snowball storage snowball = Snowballs[snowballIDs];
//         snowball.maxSlots = _maxSlots;
//         snowball.duration = _duration;
//         snowball.thresholds = _thresholds;
//         snowball.owner = payable(msg.sender);
//         snowball.startTime = block.timestamp;
//         snowball.numParticipants = 0;
//         snowball.custodyBalance = 0;
//         snowball.cohortPrices = _cohortPrices;

//         activeSnowballContractsByID.push(snowballIDs); 
//         addressToSnowballIDs[msg.sender].push(snowballIDs);
//         //emit SnowballCreated(ID);
//         snowballIDs += 1; 
//         return snowballIDs;
//     }


//     function getSnowballCurrentPrice(uint256 snowballID) public view returns (uint256) {
//         Snowball memory snowball = Snowballs[snowballID]; 
//         // Loop through the prices and stop when you get a price that is decreasing
//         for (uint256 i = 1; i < snowball.cohortPrices.length; i++) {
//             if (snowball.cohortPrices[i] < snowball.cohortPrices[i - 1]) {
//                 // Return the last price before the decrease
//                 return snowball.cohortPrices[i - 1];
//             }
//         }

//         // If all prices are strictly decreasing, return the last price
//         return snowball.cohortPrices[snowball.cohortPrices.length - 1];
//     }

//     function getSnowballUpdatedPrice(uint256 snowballID, uint256 numTickets) public view returns(uint256) {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         uint256 updatedParticipants = snowball.numParticipants + numTickets;
//         uint256 updatedPrice =snowball.cohortPrices[0]; //Set to price of first cohort
//         for (uint256 i = 0; i < snowball.thresholds.length; i++) {
//             if(updatedParticipants >= snowball.thresholds[i]) {
//                 updatedPrice = snowball.cohortPrices[i+1];
//             }
//             else{
//                 break;
//             } 
//         }
//         return updatedPrice; 
//     }

//     function updateSnowballPrices(uint256 snowballID, uint256 updatedPrice) private {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         for (uint256 i =0; i < snowball.cohortPrices.length; i++) {
//             if (snowball.cohortPrices[i] > updatedPrice) {
//                 snowball.cohortPrices[i] = updatedPrice; 
//             }
//         }
//     }

//     function joinSnowball(uint256 snowballID, uint256 numTickets) public {
//         uint256 newPrice = getSnowballUpdatedPrice(snowballID, numTickets);
//         updateSnowballPrices(snowballID, newPrice);
//         uint256 minPrice = Snowballs[snowballID].cohortPrices[Snowballs[snowballID].cohortPrices.length-1]; 
//         uint256 custodyAmount = (newPrice - minPrice);
//         if(custodyAmount !=0) {
//             usdcToken.transferFrom(msg.sender, address(this), custodyAmount*numTickets); //place custody
//             Snowballs[snowballID].custodyBalance +=custodyAmount*numTickets; 
//         }
//         uint256 commissionAmount = calculateCommission(numTickets*minPrice); 
//         usdcToken.transferFrom(msg.sender, bank, commissionAmount); //pay commissions
//         payOwner(Snowballs[snowballID].owner, numTickets*minPrice - commissionAmount);
//         Snowballs[snowballID].numParticipants +=numTickets; 

//         //Mint receipt
//         Receipt storage receipt = Receipts[receiptIDs]; 
//         receipt.snowballID = snowballID; 
//         receipt.effectivePricePaid = newPrice; 
//         receipt.owner = msg.sender; 
//         receipt.tickets = numTickets;

//         addressToReceiptIDs[msg.sender].push(receiptIDs); 
//         receiptIDs+=1; 
//     }
    
//     //Should be private. This function can be only called once for each snowball
//     function returnExcessCustody(uint256 snowballID) public {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         uint256 excessCustody;
//         //Check that the snowball has melted
//         if((block.timestamp > snowball.duration + snowball.startTime || snowball.maxSlots == snowball.numParticipants) && !snowball.returnedCustody) {
//             uint256 currentPrice = getSnowballCurrentPrice(snowballID );
//             excessCustody = (currentPrice-snowball.cohortPrices[snowball.cohortPrices.length-1]) * snowball.numParticipants; //This amount will be made available to sellers and their creditors
//             snowball.custodyBalance -= excessCustody; 
//             uint256 commissionAmount = calculateCommission(excessCustody); //Commission is on all proceeds to sellers. 
//             usdcToken.transfer(bank, commissionAmount);
//             payOwner(snowball.owner, excessCustody-commissionAmount);
//             snowball.returnedCustody = true; 
//         }
//     }

//     //Should be private?
//     function payOwner(address snowballOwner,  uint256 amount) private {
//         uint256 ownerDebt = userTotalDebt[snowballOwner]; 
//         if (ownerDebt == 0) {
//             usdcToken.transfer(snowballOwner, amount); 
//         }
//         else {
//             uint256 excess = payDebtHolders(snowballOwner, amount);
//             usdcToken.transfer(snowballOwner, excess); 
//         }
//     }

//     function receiptRedeemableAmount(uint256 receiptID) public view returns(uint256, uint256) {
//         Receipt memory receipt = Receipts[receiptID]; 
//         uint256 currentPrice = getSnowballCurrentPrice(receipt.snowballID); 
//         return (((receipt.effectivePricePaid-currentPrice) * receipt.tickets), currentPrice);
//     }

//     function redeemReceipt(uint256 receiptID) public {
//         Receipt storage receipt = Receipts[receiptID]; 
//         require(receipt.owner == msg.sender, "Not Owner");
//         (uint256 redeemableAmount, uint256 newEffectivePrice) = receiptRedeemableAmount(receiptID);
//         usdcToken.transfer(receipt.owner, redeemableAmount); 
//         receipt.effectivePricePaid = newEffectivePrice; 
//         Snowballs[receipt.snowballID].custodyBalance -= redeemableAmount;
//     }

//     function redeemMultiple(uint256[] calldata receiptList) public {
//         uint256 redeemable; 
//         for(uint256 i = 0; i < receiptList.length; i ++) {
//             Receipt storage receipt = Receipts[receiptList[i]]; 
//             require(receipt.owner == msg.sender, "Not Owner");
//             (uint256 redeemableAmount, uint256 newEffectivePrice) = receiptRedeemableAmount(receiptList[i]);
//             receipt.effectivePricePaid = newEffectivePrice; 
//             Snowballs[receipt.snowballID].custodyBalance -= redeemableAmount;
//             redeemable +=redeemableAmount;
//         }
//         usdcToken.transfer(msg.sender, redeemable);
//     }



//     //Calculates the commissions given the non-custody amount
//     function calculateCommission(uint256 totalAmount) internal view returns (uint256) { //should be internal
//         uint256 commissionAmount = totalAmount *commission/10000; 
//         return (commissionAmount);
//     }


//     function payDebtHolders(address debtor, uint256 availableAmount) private returns(uint256) {
//         uint256[] storage outstandingLoans = userOutstandingLoans[debtor];
//         uint256 closed;
//         uint256 debtSpending; 
//         for (uint256 i =0; i < outstandingLoans.length; i++) {
//             (, ,uint256 loanRemainingAmount, uint256 loanRedeemableAmount) = snowballWorkingCapital.Loans(outstandingLoans[i]);
//             uint256 newlyRedeemableAmount =  Math.min(availableAmount, loanRemainingAmount-loanRedeemableAmount);
//             availableAmount -=newlyRedeemableAmount;
//             debtSpending += newlyRedeemableAmount;
//             snowballWorkingCapital.repayDebt(outstandingLoans[i], newlyRedeemableAmount);
            
//             if (loanRemainingAmount == loanRedeemableAmount + newlyRedeemableAmount) {
//                 // This loan is fully paid off
//                 closed++;
//             }  
//             else if(closed >0) {
//                 for(uint j =0; j < outstandingLoans.length-closed; j++) {
//                     outstandingLoans[j] = outstandingLoans[j+closed];
//                 }
//                 break;
//             }
//         }
//         // Remove the closed loans by popping the last 'closed' elements
//         for (uint256 i =0; i < closed; i++) {
//             outstandingLoans.pop(); 
//         }

//         usdcToken.approve(WCProviderAddress, usdcToken.allowance(address(this), WCProviderAddress) + debtSpending);
//         userTotalDebt[debtor] -=debtSpending;

//         return availableAmount;

//     }

//     function checkUpkeep() public {
//         uint256 closeCounter;
//         bool upkeepNeeded = false;
        
//         // Loop to check for contracts that need closing or updating
//         for (uint256 i = 0; i < activeSnowballContractsByID.length; i++) {
            
//             // Check if the contract is expired or full
//             if (block.timestamp - Snowballs[activeSnowballContractsByID[i]].duration >= Snowballs[activeSnowballContractsByID[i]].startTime || Snowballs[activeSnowballContractsByID[i]].numParticipants == Snowballs[activeSnowballContractsByID[i]].maxSlots) {
//                 closeCounter += 1;
//                 upkeepNeeded = true;
//                 console.log("ID %s close.", activeSnowballContractsByID[i]);
//             }
//         }

//         // Initialize arrays of upkeeps
//         uint256[] memory toClose = new uint256[](closeCounter);
//         uint256 closeIndex;

//         // Loop again to fill the arrays
//         for (uint256 i = 0; i < activeSnowballContractsByID.length; i++) {
            
//             if (block.timestamp - Snowballs[activeSnowballContractsByID[i]].duration >= Snowballs[activeSnowballContractsByID[i]].startTime 
//             || Snowballs[activeSnowballContractsByID[i]].numParticipants == Snowballs[activeSnowballContractsByID[i]].maxSlots) {
//                 toClose[closeIndex] = i; 
//                 closeIndex += 1;
//                 console.log("Adding Snowball ID %s to close list.", activeSnowballContractsByID[i]);
//             } 
//         }

//         // Encode the data to be passed to performUpkeep
//         bytes memory performData = abi.encode(toClose);
//         performUpkeep(performData);
//         //return (upkeepNeeded, performData);
//     }

//     function performUpkeep(bytes memory performData) public {
//         if(msg.sender != s_forwarderAddress) {
//             revert NotApproved(); 
//         }
        
//         (uint256[] memory toClose) = abi.decode(
//             performData,
//             (uint256[])
//         );

//         // Close contracts
//         uint256 i = toClose.length;
//         while (i > 0) {
//             i--;
//             uint256 snowballID = activeSnowballContractsByID[toClose[i]];
//             console.log("Closing Snowball ID %s.", snowballID);
//             returnExcessCustody(snowballID); 

//             //Remove snowball from list of active snowballs
//             activeSnowballContractsByID[toClose[i]] = activeSnowballContractsByID[activeSnowballContractsByID.length - 1];
//             activeSnowballContractsByID.pop();
//             console.log("Closed ", snowballID);
//         }
//     }

//     function redeemAwards() public {
//         uint256 availableAwards = redeemableRewards[msg.sender];

//         // Check if the user has any redeemable rewards
//         require(availableAwards > 0, "No rewards to redeem");

//         // Transfer the USDC tokens to the user
//         require(usdcToken.transfer(msg.sender, availableAwards), "Token transfer failed");

//         // Update the state to reflect the redeemed rewards
//         redeemableRewards[msg.sender] = 0;
//     }

//     /// @notice Set the address that `performUpkeep` is called from
//     /// @dev Only callable by the owner
//     /// @param forwarderAddress the address to set
//     //MAKE THIS ONLY OWNER
//     function setForwarderAddress(address forwarderAddress) external onlyOwner {
//         s_forwarderAddress = forwarderAddress;
//     }

//     function setWorkingCapitalProvider(address _WCProviderAddress) external onlyOwner {
//         WCProviderAddress = _WCProviderAddress; 
//         snowballWorkingCapital = ISnowballWorkingCapital(_WCProviderAddress); 
//     }

//     function setLoanFactory(address _loanFactoryAddress) external onlyOwner {
//         loanFactory = ILoanFactory(_loanFactoryAddress); 
//     }

//     function getSnowballsByOwner(address user) public view returns (uint256[] memory) {
//         return addressToSnowballIDs[user];
//     }

//     function addUserDebt(address debtor, uint256 totalDebtAmount, uint256 loanID) external {
//         if(msg.sender != WCProviderAddress) {
//             revert NotApproved(); 
//         }
//         userOutstandingLoans[debtor].push(loanID); 
//         userTotalDebt[debtor] += totalDebtAmount; 
//     }

// }
