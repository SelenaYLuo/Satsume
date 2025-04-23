// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error NotOwner();
// error SnowballExpired();
// error InsufficientLoanEquity();
// error RequestExpired();
// error InsufficientSendAmount();
// error InvalidID();
// error InvalidConfig();
// error NotExist();
// error TransferFail();

// import "hardhat/console.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./BokkyPooBahsRedBlackTreeLibrary.sol";

// interface ISnowballContract {
//     function commission() external view returns (uint256);

//     function getSnowballMetrics(
//         uint256 id
//     )
//         external
//         view
//         returns (
//             uint256,
//             uint256,
//             uint256,
//             uint256,
//             address,
//             uint256,
//             uint256,
//             uint256,
//             uint256[] memory,
//             uint256[] memory,
//             uint256[] memory
//         );

//     function addDebtToSnowball(
//         uint256 snowballID,
//         uint256 debtAmount,
//         uint256 loanID
//     ) external returns (uint256);

//     function addUserDebt(address debtor, uint256 totalDebtAmount, uint256 loanID) external;
// }

// interface ILoanFactory {
//     function mint(
//         uint256 _faceAmount,
//         uint256 _discount,
//         uint256 _snowballID,
//         address _owner
//     ) external returns (uint256);
// }

// contract SnowballWorkingCapital5 {
//     using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;
//     struct Offer {
//         address offeror;
//         uint256 sharesOffered;
//         uint256 faceValue;
//         uint256 interestRate;
//         uint256 sharesSold;
//     }
//     struct Loan {
//         address owner;
//         address debtor;
//         uint256 remainingAmount;
//         uint256 redeemableAmount; 
//         uint256 initialAmount; 
//     }

//     mapping(uint256 => Offer) public Offers;
//     mapping(uint256 => Loan) public Loans;
//     mapping(address => uint256) public activeOffersByAddress;
//     mapping(address => uint256[]) public outstandingLoans;
    

//     uint256 public offerID = 1; //Set to 1 rather than 0 as the mappings return a zero when the key-value pairs do not exist
//     uint256 public loanID = 1; 
//     uint256 SnowballCommissionRate;
//     uint256 financingTakeRate = 20; //basis points

//     address owner;
//     address bank;
//     address snowballAddress;
//     ISnowballContract public snowballContract;
//     ILoanFactory public loanFactory;
//     IERC20 public usdcToken; // Declare the USDC token contract
//     BokkyPooBahsRedBlackTreeLibrary.Tree private requestTree;

//     constructor(address _usdcToken, address _snowballAddress) {
//         owner = msg.sender; // Set the owner to the contract deployer
//         bank = payable(owner);

//         usdcToken = IERC20(_usdcToken); // Initialize the USDC token contract
//         snowballAddress = _snowballAddress;
//         snowballContract = ISnowballContract(_snowballAddress);
//         SnowballCommissionRate = snowballContract.commission();
//     }

//     modifier onlyOwner() {
//         if (msg.sender != owner) {
//             revert NotOwner();
//         }
//         _;
//     }

//     function setLoanFactory(address _loanFactoryAddress) external onlyOwner {
//         loanFactory = ILoanFactory(_loanFactoryAddress);
//     }

//     function setBank(address payable newBank) external onlyOwner {
//         bank = payable(newBank);
//     }

//     function makeOffer(uint256 _sharesOffered, uint256 _faceValue, uint256 _interestRate) public {
//         Offer storage offer = Offers[offerID];
//         offer.offeror = msg.sender;
//         offer.faceValue = _faceValue;
//         offer.sharesOffered = _sharesOffered;
//         offer.interestRate = _interestRate;
//         activeOffersByAddress[msg.sender] = offerID;
//         offerID +=1;
//     }

//     function acceptOffer(uint256 _offerID, uint256 numShares) public {
//         Offer storage offer = Offers[_offerID];
//         Loan storage loan = Loans[loanID];
        
//         // Validate offer ID and ensure not exceeding available shares
//         require(_offerID == activeOffersByAddress[offer.offeror], "Invalid offer");
//         require(offer.sharesSold + numShares <= offer.sharesOffered, "Too many shares");

//         // Set loan details
//         loan.debtor = offer.offeror;
//         loan.owner = msg.sender;

//         // Calculate remaining amount and commission
//         uint256 faceValue = offer.faceValue;
//         uint256 interestRate = offer.interestRate;
//         uint256 totalFaceValue = faceValue * numShares;
        
//         // Use fixed-point arithmetic for precision
//         uint256 _remainingAmount = totalFaceValue * (10000 + interestRate) / 10000;
//         loan.remainingAmount = _remainingAmount;
//         loan.initialAmount = _remainingAmount; 
//         uint256 commissionAmount = financingTakeRate * totalFaceValue / 10000;

//         // Transfer USDC tokens
//         bool success = usdcToken.transferFrom(msg.sender, bank, commissionAmount);
//         require(success, "Commission transfer failed");
        
//         uint256 amountToOfferor = totalFaceValue - commissionAmount;
//         success = usdcToken.transferFrom(msg.sender, offer.offeror, amountToOfferor);
//         require(success, "Offeror transfer failed");

//         // Update offer and loan records
//         offer.sharesSold += numShares;
//         snowballContract.addUserDebt(offer.offeror, _remainingAmount, loanID);
//         loanID +=1; 
//     }

//     function repayDebt(uint256 _loanID, uint256 repaymentAmount) external {
//         if (msg.sender != snowballAddress) revert NotOwner();
//         Loan storage loan = Loans[_loanID];
//         loan.redeemableAmount +=repaymentAmount; 
//     }
    
//     function redeemDebt(uint256 _loanID) public {
//         Loan storage loan = Loans[_loanID];
//         if(loan.owner!= msg.sender) revert NotOwner();
//         bool success = usdcToken.transferFrom(snowballAddress, msg.sender, loan.redeemableAmount);
//         loan.remainingAmount -= redeemableAmount; 
//         loan.redeemableAmount = 0;
//     }


//     function acceptRequest(uint256 requestID) public payable {
//         //requestID 0 occurs when requests are deleted
//         if (requestID == 0) {
//             revert InvalidConfig();
//         }

//         // Fetch the snowball metrics and save variables to memory for efficient access
//         SnowballMetrics memory metrics = getSnowballMetrics(
//             Requests[requestID].snowballID
//         );
//         Request memory request = Requests[requestID];
//         // uint256 requestAmount = Requests[requestID].requestAmount;
//         // uint256 requestDiscount = Requests[requestID].requestDiscount;
//         // uint256 snowballID = Requests[requestID].snowballID;
//         address SnowballOwner = Requests[requestID].owner;

//         // Calculate the requestable amount
//         uint256 requestableAmount = availableWorkingCapital(metrics);

//         console.log("Requestable Amount:", requestableAmount);

//         // Check if the request is still valid
//         if (
//             requestableAmount < request.requestAmount ||
//             metrics.startTime + metrics.duration < block.timestamp ||
//             Requests[requestID].startingTransactions +
//                 Requests[requestID].requestActiveTransactions <
//             metrics.numParticipants ||
//             Requests[requestID].requestActiveDuration +
//                 Requests[requestID].startTime <
//             block.timestamp ||
//             metrics.numParticipants > metrics.maxSlots
//         ) {
//             revert RequestExpired();
//         }

//         // Calculate the amount to be sent
//         uint256 baseAmount = (request.requestAmount *
//             (10000 - request.requestDiscount)) / 10000;
//         uint256 commission = (baseAmount * financingTakeRate) /
//             10000;
//         uint256 amountToBeSent = baseAmount + commission;

//         console.log("Amount to be sent:", amountToBeSent);
//         // Create the loan
//         uint256 loanID = loanFactory.mint(
//             request.requestAmount,
//             request.requestDiscount,
//             request.snowballID,
//             msg.sender
//         );

//         // Add debt to the snowball
//         uint256 tranche = snowballContract.addDebtToSnowball(
//             request.snowballID,
//             request.requestAmount,
//             loanID
//         );
//         console.log("Tranche:", tranche);

//         console.log("1");
//         // Remove the request from the appropriate mappings
//         _deleteRequest(requestID);
//         console.log("2");
//         // Send the commission and loans
//         bool success = usdcToken.transferFrom(msg.sender, bank, commission);
//         if (!success) {
//             revert TransferFail();
//         }

//         success = usdcToken.transferFrom(msg.sender, SnowballOwner, baseAmount);
//         if (!success) {
//             revert TransferFail();
//         }
//     }

//     function RequestWorkingCapital(
//         uint256 snowballID,
//         uint256 discount,
//         uint256 amount,
//         uint256 duration,
//         uint256 transactions
//     ) public {
//         SnowballMetrics memory metrics = getSnowballMetrics(snowballID);
//         if (metrics.owner != msg.sender) {
//             revert NotOwner();
//         } else if (
//             metrics.startTime + metrics.duration < block.timestamp ||
//             metrics.numParticipants >= metrics.maxSlots
//         ) {
//             revert SnowballExpired();
//         } else if (
//             discount >= 10000 ||
//             amount < 1 ||
//             duration > 315_569_260 ||
//             amount < 1
//         ) {
//             revert InvalidConfig();
//         }
//         uint256 requestableAmount = availableWorkingCapital(metrics);
//         if (amount <= requestableAmount) {
//             Request storage newWCRequest = Requests[requestIDCounter];
//             newWCRequest.snowballID = snowballID;
//             newWCRequest.requestActiveDuration = duration;
//             newWCRequest.requestActiveTransactions = transactions;
//             newWCRequest.startingTransactions = metrics.numParticipants;
//             newWCRequest.requestAmount = amount;
//             newWCRequest.requestDiscount = discount;
//             newWCRequest.requestID = requestIDCounter;
//             newWCRequest.startTime = block.timestamp;
//             newWCRequest.owner = msg.sender;

//             //update state
//             snowballIDToWCRequestID[snowballID].push(requestIDCounter);
//             if (!requestTree.exists(discount)) {
//                 requestTree.insert(discount);
//             }
//             discountToRequests[discount].push(requestIDCounter);
//             requestIDCounter += 1;
//         } else {
//             revert InsufficientLoanEquity();
//         }
//     }

//     function removeRequestFromTree(
//         uint256 requestID,
//         uint256 discount
//     ) private {
//         console.log("111");
//         uint256[] storage requestList = discountToRequests[discount];
//         for (uint256 i = 0; i < requestList.length; i++) {
//             if (requestList[i] == requestID) {
//                 requestList[i] = requestList[requestList.length - 1];
//                 requestList.pop();
//                 break;
//             }
//         }
//         console.log("222");
//         if (requestList.length == 0) {
//             requestTree.remove(discount);
//         }
//     }

//     // Function to get a specific number active requests in order of their discounts from largest to smallest
//     function getActiveRequests(
//         uint256 numberToReturn
//     ) public view returns (uint256[] memory) {
//         uint256[] memory requestIds = new uint256[](numberToReturn);
//         uint256 count = 0;
//         uint256 currentKey = requestTree.first();

//         while (
//             count < numberToReturn &&
//             currentKey != BokkyPooBahsRedBlackTreeLibrary.getEmpty()
//         ) {
//             uint256[] storage requests = discountToRequests[currentKey];
//             for (
//                 uint256 i = 0;
//                 i < requests.length && count < numberToReturn;
//                 i++
//             ) {
//                 requestIds[count] = requests[i];
//                 count++;
//             }
//             currentKey = requestTree.next(currentKey);
//         }

//         // If we didn't fill the entire array, we need to trim it
//         if (count < numberToReturn) {
//             uint256[] memory trimmedRequestIds = new uint256[](count);
//             for (uint256 i = 0; i < count; i++) {
//                 trimmedRequestIds[i] = requestIds[i];
//             }
//             return trimmedRequestIds;
//         }

//         return requestIds;
//     }

//     // Function to get a specific range active requests in order of their discounts from largest to smallest
//     function getActiveRequestsRange(
//         uint256 start,
//         uint256 end
//     ) public view returns (uint256[] memory) {
//         require(start <= end, "Start must be less than or equal to end");

//         uint256[] memory requestIds = new uint256[](end - start + 1);
//         uint256 count = 0;
//         uint256 currentKey = requestTree.first();
//         uint256 totalProcessed = 0;

//         while (count < (end - start + 1) && currentKey != 0) {
//             uint256[] storage requests = discountToRequests[currentKey];
//             for (uint256 i = 0; i < requests.length; i++) {
//                 if (totalProcessed >= start && totalProcessed <= end) {
//                     requestIds[count] = requests[i];
//                     count++;
//                 }
//                 totalProcessed++;
//                 if (count == (end - start + 1)) {
//                     break;
//                 }
//             }
//             currentKey = requestTree.next(currentKey);
//         }

//         // If we didn't fill the entire array, we need to trim it
//         if (count < (end - start + 1)) {
//             uint256[] memory trimmedRequestIds = new uint256[](count);
//             for (uint256 i = 0; i < count; i++) {
//                 trimmedRequestIds[i] = requestIds[i];
//             }
//             return trimmedRequestIds;
//         }

//         return requestIds;
//     }

//     function deleteAllSnowballRequests(uint256 snowballID) public {
//         uint256[] memory requestIDs = snowballIDToWCRequestID[snowballID];
//         if (
//             msg.sender != Requests[requestIDs[0]].owner &&
//             msg.sender != snowballAddress
//         ) revert NotOwner();
//         for (uint256 i = 0; i < requestIDs.length; i++) {
//             removeRequestFromTree(
//                 requestIDs[i],
//                 Requests[requestIDs[i]].requestDiscount
//             );
//             delete Requests[requestIDs[i]];
//         }
//         delete snowballIDToWCRequestID[snowballID];
//     }

//     function deleteRequest(uint256 requestID) public {
//         console.log("22");
//         Request storage request = Requests[requestID];
//         if (request.owner != msg.sender) revert NotOwner();
//         console.log("33");
//         uint256[] storage snowballRequests = snowballIDToWCRequestID[
//             request.snowballID
//         ];
//         removeRequestFromTree(requestID, Requests[requestID].requestDiscount);
//         console.log("44");
//         delete Requests[requestID];
//         console.log("55");
//         // Find and remove the request ID from the snowballIDToWCRequestID mapping
//         for (uint256 j = 0; j < snowballRequests.length; j++) {
//             if (snowballRequests[j] == requestID) {
//                 snowballRequests[j] = snowballRequests[
//                     snowballRequests.length - 1
//                 ];
//                 snowballRequests.pop(); // Remove the last element
//                 break;
//             }
//         }
//     }

//     function _deleteRequest(uint256 requestID) private {
//         console.log("22");
//         Request storage request = Requests[requestID];
//         console.log("33");
//         uint256[] storage snowballRequests = snowballIDToWCRequestID[
//             request.snowballID
//         ];
//         removeRequestFromTree(requestID, Requests[requestID].requestDiscount);
//         console.log("44");
//         delete Requests[requestID];
//         console.log("55");
//         // Find and remove the request ID from the snowballIDToWCRequestID mapping
//         for (uint256 j = 0; j < snowballRequests.length; j++) {
//             if (snowballRequests[j] == requestID) {
//                 snowballRequests[j] = snowballRequests[
//                     snowballRequests.length - 1
//                 ];
//                 snowballRequests.pop(); // Remove the last element
//                 break;
//             }
//         }
//     }

//     function availableWorkingCapital(
//         SnowballMetrics memory metrics
//     ) public view returns (uint256) {
//         //Find outstanding liabilities - cohorts which we have already passed but have not paid out the participants.
//         uint256 remainingPriceReductions = 0;
//         bool outstandingLiability = false;
//         for (uint256 i = 0; i < metrics.thresholds.length; i++) {
//             if (metrics.numParticipants < metrics.thresholds[i]) {
//                 remainingPriceReductions = metrics.thresholds.length - i;
//                 break;
//             } else if (metrics.cohortPrices[i] > metrics.price) {
//                 outstandingLiability = true;
//             }
//         }

//         // Log price reductions and liability
//         console.log("outstandingLiability: %s", outstandingLiability);

//         // Calculate the outstanding liability to deduct from snowball balance
//         uint256 liabilityAmount;
//         if (outstandingLiability) {
//             uint256 i = 0;
//             while (
//                 metrics.cohortPrices[i] > metrics.price &&
//                 i < metrics.cohortPrices.length
//             ) {
//                 //&& metrics.numParticipants > metrics.thresholds[i]) {
//                 //uint256 numTickets = cohortTicketAmounts[i];
//                 //uint256 rebateAmount = cohortPrices[i] - price;
//                 liabilityAmount +=
//                     metrics.cohortTicketAmounts[i] *
//                     (metrics.cohortPrices[i] - metrics.price);
//                 i++;
//             }
//         }

//         // Log liability amount
//         console.log("liabilityAmount: %s", liabilityAmount);

//         // Calculate the minimum revenue the snowball owner will receive. Initially set to the current balance minus liability, commission and debt - the outcome corresponding to no more additional sales in the snowball
//         uint256 currentMinimum = (metrics.balance - liabilityAmount) -
//             (((metrics.balance - liabilityAmount) * SnowballCommissionRate) /
//                 10000) -
//             metrics.totalDebt;
//         //simplify the above

//         // Calculate the remaining revenue to the snowball owner at each threshold net of commissions and outstanding debt
//         if (remainingPriceReductions > 0) {
//             //Loop backwards as price reductions correspond to thresholds at the end of the array
//             for (uint256 i = metrics.thresholds.length - 1; i >= 0; i--) {
//                 if (metrics.numParticipants < metrics.thresholds[i]) {
//                     uint256 revenue = ((metrics.thresholds[i] -
//                         metrics.numParticipants) *
//                         (metrics.cohortPrices[i + 1])) +
//                         ((metrics.balance - liabilityAmount) -
//                             (metrics.numParticipants *
//                                 (metrics.price - metrics.cohortPrices[i + 1])));
//                     revenue =
//                         revenue -
//                         ((revenue * SnowballCommissionRate) / 10000) -
//                         metrics.totalDebt;
//                     console.log("revenuesAtThresholds[%s]: %s", i, revenue);
//                     if (revenue < currentMinimum) currentMinimum = revenue;
//                     if (i == 0) break;
//                 }
//             }
//         }

//         // Log final minimum value
//         console.log("minimum: %s", currentMinimum);

//         return currentMinimum;
//     }

//     function getRequestsBySnowballID(
//         uint256 snowballID
//     ) public view returns (uint256[] memory) {
//         return snowballIDToWCRequestID[snowballID];
//     }

//     function getActiveRequestIDs() public view returns (uint256[] memory) {
//         uint256 activeRequestCount = 0;

//         // Count the number of active requests
//         for (uint256 i = 0; i < requestIDCounter; i++) {
//             if (Requests[i].owner != address(0)) {
//                 activeRequestCount++;
//             }
//         }

//         // Create an array to store active requests
//         uint256[] memory activeRequests = new uint256[](activeRequestCount);
//         uint256 currentIndex = 0;

//         for (uint256 i = 0; i < requestIDCounter; i++) {
//             if (Requests[i].owner != address(0)) {
//                 activeRequests[currentIndex] = Requests[i].requestID;
//                 currentIndex++;
//             }
//         }
//         return activeRequests;
//     }

//     function getRequest(
//         uint256 requestID
//     ) public view returns (Request memory) {
//         if (Requests[requestID].requestID == 0) {
//             revert NotExist();
//         }
//         return Requests[requestID];
//     }

//     function getSnowballMetrics(
//         uint256 snowballID
//     ) public view returns (SnowballMetrics memory) {
//         (
//             uint256 price,
//             uint256 maxSlots,
//             uint256 duration,
//             uint256 totalDebt,
//             address snowballOwner,
//             uint256 startTime,
//             uint256 numParticipants,
//             uint256 balance,
//             uint256[] memory cohortTicketAmounts,
//             uint256[] memory cohortPrices,
//             uint256[] memory thresholds
//         ) = snowballContract.getSnowballMetrics(snowballID);

//         return
//             SnowballMetrics({
//                 price: price,
//                 maxSlots: maxSlots,
//                 duration: duration,
//                 totalDebt: totalDebt,
//                 owner: snowballOwner,
//                 startTime: startTime,
//                 numParticipants: numParticipants,
//                 balance: balance,
//                 cohortTicketAmounts: cohortTicketAmounts,
//                 cohortPrices: cohortPrices,
//                 thresholds: thresholds
//             });
//     }
// }
