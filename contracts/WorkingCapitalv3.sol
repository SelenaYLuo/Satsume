// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error NotOwner();
error SnowballExpired();
error InsufficientLoanEquity();
error RequestExpired();
error InsufficientSendAmount();
error InvalidID();
error InvalidConfig();
error NotExist();
error TransferFail();

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISnowballContract {
    function commission() external view returns (uint256);

    function getSnowballMetrics(
        uint256 id
    )
        external
        view
        returns (
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
        );

    function AddDebtToSnowball(
        uint256 snowballID,
        uint256 debtAmount,
        address debtOwner,
        uint256 loanID
    ) external returns (uint256);

    function getSnowballLoans(
        uint256 snowballID
    ) external view returns (uint256[] memory);

    function setNewTrancheOwner(
        uint256 snowballID,
        uint256 tranche,
        address newOwner
    ) external;
}

contract SnowballWorkingCapital3 is ERC721 {
    struct Loan {
        uint256 snowballID;
        uint256 amountOutstanding;
        uint256 tranche;
        uint256 ID;
        address owner;
    }

    struct Request {
        uint256 snowballID;
        uint256 requestActiveDuration;
        uint256 startingTransactions;
        uint256 requestActiveTransactions;
        uint256 requestAmount;
        uint256 requestDiscount;
        uint256 requestID;
        uint256 startTime;
        address owner;
    }

    struct SnowballMetrics {
        uint256 price;
        uint256 maxSlots;
        uint256 duration;
        uint256 totalDebt;
        address owner;
        uint256 startTime;
        uint256 numParticipants;
        uint256 balance;
        uint256[] cohortTicketAmounts;
        uint256[] cohortPrices;
        uint256[] thresholds;
    }

    mapping(uint256 => Loan) public Loans;
    mapping(uint256 => Request) public Requests;
    mapping(uint256 => uint256[]) public snowballIDToWCRequestID;
    mapping(uint256 => uint256[]) public snowballIDToLoanIDPerTranche; //The IDs for the i-indexed loan tranche are in i-th index of the array.

    uint256 public loanIDCounter = 1; //should be set to private and set to one?
    uint256 public requestIDCounter = 1; //Set to 1 rather than 0 as the mappings return a zero when the key-value pairs do not exist
    uint256 SnowballCommissionRate;
    uint256 WorkingCapitalCommissionRate = 20;

    address owner;
    address bank;
    address snowballAddress;
    ISnowballContract public snowballContract;
    IERC20 public usdcToken; // Declare the USDC token contract

    constructor(address _usdcToken) ERC721("SnowballWorkingCapital", "SBWC") {
        owner = msg.sender; // Set the owner to the contract deployer
        bank = payable(owner);
        usdcToken = IERC20(_usdcToken); // Initialize the USDC token contract
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    //Set the address for the snowball contract for which to provide working capital
    function setSnowballContract(address _snowballAddress) public onlyOwner {
        snowballAddress = _snowballAddress;
        snowballContract = ISnowballContract(_snowballAddress);
        SnowballCommissionRate = snowballContract.commission();
    }

    function setBank(address payable newBank) external onlyOwner {
        bank = payable(newBank);
    }

    function acceptRequest(uint256 requestID) public payable {
        //requestID 0 occurs when requests are deleted
        if (requestID == 0) {
            revert InvalidConfig();
        }

        // Fetch the request
        //Request storage request = Requests[requestID];

        // Fetch the snowball metrics and save variables to memory for efficient access
        SnowballMetrics memory metrics = getSnowballMetrics(
            Requests[requestID].snowballID
        );
        uint256 requestAmount = Requests[requestID].requestAmount;
        uint256 requestDiscount = Requests[requestID].requestDiscount;
        uint256 snowballID = Requests[requestID].snowballID;
        address SnowballOwner = Requests[requestID].owner;

        // Calculate the requestable amount
        uint256 requestableAmount = availableWorkingCapital(metrics);

        console.log("Requestable Amount:", requestableAmount);

        // Check if the request is still valid
        if (
            requestableAmount < requestAmount ||
            metrics.startTime + metrics.duration < block.timestamp ||
            Requests[requestID].startingTransactions +
                Requests[requestID].requestActiveTransactions <
            metrics.numParticipants ||
            Requests[requestID].requestActiveDuration +
                Requests[requestID].startTime <
            block.timestamp ||
            metrics.numParticipants > metrics.maxSlots
        ) {
            revert RequestExpired();
        }

        // Calculate the amount to be sent
        uint256 baseAmount = (requestAmount * (10000 - requestDiscount)) /
            10000;
        uint256 commission = (baseAmount * WorkingCapitalCommissionRate) /
            10000;
        uint256 amountToBeSent = baseAmount + commission;

        console.log("Amount to be sent:", amountToBeSent);

        // Add debt to the snowball
        uint256 tranche = snowballContract.AddDebtToSnowball(
            snowballID,
            requestAmount,
            msg.sender,
            loanIDCounter
        );
        console.log("Tranche:", tranche);

        // Create the loan
        MakeLoan(snowballID, requestAmount, tranche);
        console.log("1");
        // Remove the request from the appropriate mappings
        uint256[] memory toDelete = new uint256[](1);
        toDelete[0] = requestID;
        deleteRequests(toDelete);
        console.log("2");
        // Send the commission and loans
        bool success = usdcToken.transferFrom(msg.sender, bank, commission);
        if (!success) {
            revert TransferFail();
        }

        success = usdcToken.transferFrom(msg.sender, SnowballOwner, baseAmount);
        if (!success) {
            revert TransferFail();
        }
    }

    function UpdateLoanAmount(uint256 loanID, uint256 subtractAmount) public {
        //require(msg.sender == snowballAddress, "NotCertified");
        Loans[loanID].amountOutstanding -= subtractAmount;
    }

    function UpdateLoanTranche(uint256 loanID, uint256 newTranche) public {
        //require(msg.sender == snowballAddress, "NotCertified");
        Loans[loanID].tranche = newTranche;
    }

    function RequestWorkingCapital(
        uint256 snowballID,
        uint256 discount,
        uint256 amount,
        uint256 duration,
        uint256 transactions
    ) public {
        SnowballMetrics memory metrics = getSnowballMetrics(snowballID);
        if (metrics.owner != msg.sender) {
            revert NotOwner();
        } else if (
            metrics.startTime + metrics.duration < block.timestamp ||
            metrics.numParticipants >= metrics.maxSlots
        ) {
            revert SnowballExpired();
        } else if (
            discount >= 10000 ||
            amount < 1 ||
            duration > 315_569_260 ||
            amount < 1
        ) {
            revert InvalidConfig();
        }
        uint256 requestableAmount = availableWorkingCapital(metrics);
        if (amount <= requestableAmount) {
            Request storage newWCRequest = Requests[requestIDCounter];
            newWCRequest.snowballID = snowballID;
            newWCRequest.requestActiveDuration = duration;
            newWCRequest.requestActiveTransactions = transactions;
            newWCRequest.startingTransactions = metrics.numParticipants;
            newWCRequest.requestAmount = amount;
            newWCRequest.requestDiscount = discount;
            newWCRequest.requestID = requestIDCounter;
            newWCRequest.startTime = block.timestamp;
            newWCRequest.owner = msg.sender;

            //update state
            snowballIDToWCRequestID[snowballID].push(requestIDCounter);
            requestIDCounter += 1;
        } else {
            revert InsufficientLoanEquity();
        }
    }

    function _deleteRequests(uint256[] memory requestIDs) internal {}

    //Optimal to only delete requests from the same snowball
    function deleteRequests(uint256[] memory requestIDs) public {
        // Ensure there are requests to delete
        if (requestIDs.length == 0) {
            return; // Exit early if there are no requests to process
        }

        uint256 snowballID = Requests[requestIDs[0]].snowballID; // Get the snowball ID from the first request
        uint256[] storage snowballRequests = snowballIDToWCRequestID[
            snowballID
        ]; // Get the list of requests for the snowball ID
        address requestOwner = Requests[requestIDs[0]].owner;
        console.log(tx.origin);
        console.log(address(this));
        if (
            msg.sender != requestOwner &&
            tx.origin != address(this) &&
            msg.sender != snowballAddress
        ) {
            revert NotOwner();
        }
        console.log("a");

        // Iterate through each request ID
        for (uint256 i = 0; i < requestIDs.length; i++) {
            // Ensure all requests have the same snowball ID
            if (Requests[requestIDs[i]].snowballID != snowballID) {
                revert InvalidConfig(); // Revert if there's a mismatch in snowball IDs
            }

            // Remove the request from the Requests mapping by clearing fields
            delete Requests[requestIDs[i]];

            // Find and remove the request ID from the snowballIDToWCRequestID mapping
            for (uint256 j = 0; j < snowballRequests.length; j++) {
                if (snowballRequests[j] == requestIDs[i]) {
                    snowballRequests[j] = snowballRequests[
                        snowballRequests.length - 1
                    ];
                    snowballRequests.pop(); // Remove the last element
                    break;
                }
            }
        }
        snowballIDToWCRequestID[snowballID] = snowballRequests; // Update the modified array back to storage
    }

    // function modifyRequest(
    //     uint256 requestID,
    //     uint256 newDiscount,
    //     uint256 newAmount,
    //     uint256 newDuration,
    //     uint256 newTransactions
    // ) public {
    //     Request memory request = Requests[requestID];
    //     if (request.owner != msg.sender) {
    //         revert NotOwner();
    //     }
    //     SnowballMetrics memory metrics = getSnowballMetrics(request.snowballID);
    //     if (
    //         metrics.startTime + metrics.duration < block.timestamp ||
    //         metrics.numParticipants >= metrics.maxSlots
    //     ) {
    //         revert SnowballExpired();
    //     } else if (
    //         newDiscount >= 10000 || newAmount < 1 || newDuration > 315_569_260
    //     ) {
    //         revert InvalidConfig();
    //     }

    //     if (request.requestAmount != newAmount) {
    //         uint256 requestableAmount = availableWorkingCapital(metrics);
    //         if (newAmount <= requestableAmount) {
    //             Requests[requestID].requestAmount = newAmount;
    //         } else {
    //             revert InsufficientLoanEquity();
    //         }
    //     }
    //     if (request.requestActiveDuration != newDuration) {
    //         Requests[requestID].requestActiveDuration = newDuration;
    //     }
    //     if (request.requestActiveTransactions != newTransactions) {
    //         Requests[requestID].requestActiveTransactions = newTransactions;
    //     }
    //     if (request.requestDiscount != newDiscount) {
    //         Requests[requestID].requestDiscount = newDiscount;
    //     }
    // }

    function availableWorkingCapital(
        SnowballMetrics memory metrics
    ) public view returns (uint256) {
        //Find outstanding liabilities - cohorts which we have already passed but have not paid out the participants.
        uint256 remainingPriceReductions = 0;
        bool outstandingLiability = false;
        for (uint256 i = 0; i < metrics.thresholds.length; i++) {
            if (metrics.numParticipants < metrics.thresholds[i]) {
                remainingPriceReductions = metrics.thresholds.length - i;
                break;
            } else if (metrics.cohortPrices[i] > metrics.price) {
                outstandingLiability = true;
            }
        }

        // Log price reductions and liability
        console.log("outstandingLiability: %s", outstandingLiability);

        // Calculate the outstanding liability to deduct from snowball balance
        uint256 liabilityAmount;
        if (outstandingLiability) {
            uint256 i = 0;
            while (
                metrics.cohortPrices[i] > metrics.price &&
                i < metrics.cohortPrices.length
            ) {
                //&& metrics.numParticipants > metrics.thresholds[i]) {
                //uint256 numTickets = cohortTicketAmounts[i];
                //uint256 rebateAmount = cohortPrices[i] - price;
                liabilityAmount +=
                    metrics.cohortTicketAmounts[i] *
                    (metrics.cohortPrices[i] - metrics.price);
                i++;
            }
        }

        // Log liability amount
        console.log("liabilityAmount: %s", liabilityAmount);

        // Calculate the minimum revenue the snowball owner will receive. Initially set to the current balance minus liability, commission and debt - the outcome corresponding to no more additional sales in the snowball
        uint256 currentMinimum = (metrics.balance - liabilityAmount) -
            (((metrics.balance - liabilityAmount) * SnowballCommissionRate) /
                10000) -
            metrics.totalDebt;
        //simplify the above

        // Calculate the remaining revenue to the snowball owner at each threshold net of commissions and outstanding debt
        if (remainingPriceReductions > 0) {
            //Loop backwards as price reductions correspond to thresholds at the end of the array
            for (uint256 i = metrics.thresholds.length - 1; i >= 0; i--) {
                if (metrics.numParticipants < metrics.thresholds[i]) {
                    uint256 revenue = ((metrics.thresholds[i] -
                        metrics.numParticipants) *
                        (metrics.cohortPrices[i + 1])) +
                        ((metrics.balance - liabilityAmount) -
                            (metrics.numParticipants *
                                (metrics.price - metrics.cohortPrices[i + 1])));
                    revenue =
                        revenue -
                        ((revenue * SnowballCommissionRate) / 10000) -
                        metrics.totalDebt;
                    console.log("revenuesAtThresholds[%s]: %s", i, revenue);
                    if (revenue < currentMinimum) currentMinimum = revenue;
                    if (i == 0) break;
                }
            }
        }

        // Log final minimum value
        console.log("minimum: %s", currentMinimum);

        return currentMinimum;
    }

    function MakeLoan(
        uint256 _snowballID,
        uint256 _amount,
        uint256 _tranche
    ) public {
        Loan memory newLoan = Loan({
            snowballID: _snowballID,
            amountOutstanding: _amount,
            tranche: _tranche,
            ID: loanIDCounter,
            owner: msg.sender
        });
        Loans[loanIDCounter] = newLoan;
        snowballIDToLoanIDPerTranche[_snowballID].push(loanIDCounter);

        // Mint a new SWBC token with loan details to the loan owner
        _safeMint(msg.sender, loanIDCounter);

        loanIDCounter += 1;
    }

    function transferLoan(uint256 loanID, address newOwner) public {
        Loan storage loan = Loans[loanID];
        // Ensure the caller is the current owner of the loan
        if (loan.owner != msg.sender) {
            revert NotOwner();
        }

        if (loan.ID == 0) {
            revert NotExist();
        }

        // Update tranche ownership on the snowball contract
        uint256[] memory loanByTranche = snowballContract.getSnowballLoans(
            loan.snowballID
        );
        uint256 index;
        for (uint256 i = 0; i < loanByTranche.length; i++) {
            if (loanByTranche[i] == loanID) {
                index = i;
                break;
            }
        }
        //Update the snowball debt tranches
        snowballContract.setNewTrancheOwner(loan.snowballID, index, newOwner);

        // Transfer the ownership of the loan to the new owner
        Loans[loanID].owner = newOwner;

        // Transfer the SWBC token ownership to the new owner
        _transfer(msg.sender, newOwner, loanID);
    }

    function burnToken(uint256 tokenID) public {
        // Ensure the caller is the owner of the token
        //require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: burn caller is not owner nor approved");

        // Burn the token
        _burn(tokenID);

        // Update the loan information from the loan mappings
        uint256 snowballID = Loans[tokenID].snowballID;
        for (
            uint256 i = 0;
            i < snowballIDToLoanIDPerTranche[snowballID].length - 1;
            i++
        ) {
            snowballIDToLoanIDPerTranche[snowballID][
                i
            ] = snowballIDToLoanIDPerTranche[snowballID][i + 1];
        }
        snowballIDToLoanIDPerTranche[snowballID].pop();
        delete Loans[tokenID];
    }

    function getActiveLoanIDs() public view returns (uint256[] memory) {
        uint256 activeLoanCount = 0;

        // Count the number of active loans
        for (uint256 i = 0; i < loanIDCounter; i++) {
            if (Loans[i].owner != address(0)) {
                activeLoanCount++;
            }
        }

        // Create an array to store active loans
        uint256[] memory activeLoans = new uint256[](activeLoanCount);
        uint256 currentIndex = 0;

        // Add active loan IDs to the array
        for (uint256 i = 0; i < loanIDCounter; i++) {
            if (Loans[i].owner != address(0)) {
                activeLoans[currentIndex] = Loans[i].ID;
                currentIndex++;
            }
        }

        return activeLoans;
    }

    function getLoan(uint256 loanID) public view returns (Loan memory) {
        if (Loans[loanID].ID == 0) {
            revert NotExist();
        }
        return Loans[loanID];
    }

    function getRequestsBySnowballID(
        uint256 snowballID
    ) public view returns (uint256[] memory) {
        return snowballIDToWCRequestID[snowballID];
    }

    function getActiveRequestIDs() public view returns (uint256[] memory) {
        uint256 activeRequestCount = 0;

        // Count the number of active loans
        for (uint256 i = 0; i < requestIDCounter; i++) {
            if (Requests[i].owner != address(0)) {
                activeRequestCount++;
            }
        }

        // Create an array to store active loans
        uint256[] memory activeRequests = new uint256[](activeRequestCount);
        uint256 currentIndex = 0;

        // Add active loan IDs to the array
        for (uint256 i = 0; i < requestIDCounter; i++) {
            if (Requests[i].owner != address(0)) {
                activeRequests[currentIndex] = Requests[i].requestID;
                currentIndex++;
            }
        }
        return activeRequests;
    }

    function getRequest(
        uint256 requestID
    ) public view returns (Request memory) {
        if (Requests[requestID].requestID == 0) {
            revert NotExist();
        }
        return Requests[requestID];
    }

    function getSnowballMetrics(
        uint256 snowballID
    ) public view returns (SnowballMetrics memory) {
        (
            uint256 price,
            uint256 maxSlots,
            uint256 duration,
            uint256 totalDebt,
            address snowballOwner,
            uint256 startTime,
            uint256 numParticipants,
            uint256 balance,
            uint256[] memory cohortTicketAmounts,
            uint256[] memory cohortPrices,
            uint256[] memory thresholds
        ) = snowballContract.getSnowballMetrics(snowballID);

        return
            SnowballMetrics({
                price: price,
                maxSlots: maxSlots,
                duration: duration,
                totalDebt: totalDebt,
                owner: snowballOwner,
                startTime: startTime,
                numParticipants: numParticipants,
                balance: balance,
                cohortTicketAmounts: cohortTicketAmounts,
                cohortPrices: cohortPrices,
                thresholds: thresholds
            });
    }
}
