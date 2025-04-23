// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error Snowball_InsufficientFund();
// error Promotion_Expired();
// error NoFundsToDistribute();
// error InvalidConfig(); 
// error TransferFail();
// error NotApproved();
// error AlreadyDrawn();
// error IneligibleDrawing(); 
// event SnowballCreated(uint256 snowballId);

// event DrawingCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 maxSlots, uint256 duration, uint256 startTime, uint256 price, uint256 cohortSize, uint256 rebateAmount);
// event DrawingJoined(address indexed joiner, uint256 indexed promotionID, uint256 indexed firstParticipantNumber, uint256 firstTokenID, uint256 numTickets);
// event RaffleWinner(uint256 indexed promotionID, uint256 cohort, uint256 tokenID, uint256 participantNumber, uint256 prize); 
// event RaffleInitiated(uint256 indexed promotionID, uint256 indexed vrfRequestID, address indexed initiator, uint256 cohort); //initiators should be reimbursed more in potential air-drops
// event DrawingCustodyRedeemed(uint256 indexed promotionID, uint256 redeemedAmount); 
// event DrawingCancelled(uint256 indexed promotionID, uint256 numberOfParticipants);

// event SnowballCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 maxSlots, uint256 duration, uint256 startTime, uint256[] thresholds, uint256[] cohortPrices);
// event SnowballJoined(address indexed joiner, uint256 indexed promotionID, uint256 firstParticipantNumber, uint256 firstTokenID, uint256 pricePaid, uint256 numTickets);
// event SnowballCustodyRedeemed(uint256 indexed promotionID, uint256 redeemedAmount); 
// event SnowballCancelled(uint256 indexed promotionID, uint256 numberOfParticipants);

// event SeedCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 seeds, uint256 maxSlots, uint256 sharedAmount, uint256 duration, uint256 startTime );
// event SeedJoined(address indexed joiner, uint256 promotionID, uint256 firstParticipantNumber, uint256  firstTokenID, bool seeded, uint256 numTickets);
// event SeedCancelled(uint256 indexed promotionID, uint256 numberOfParticipants); 

// event OperatorApproved(address indexed owner, address indexed approvedOperator);
// event OperatorRemoved(address indexed owner, address indexed removedOperator);

// import "hardhat/console.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// interface IReceiptManager {
//     function createSnowballReceipts(
//         address to,
//         uint256 promotionID,
//         uint256 startParticipantNumber,
//         uint256 effectivePricePaid,
//         address erc20TokenAddress,
//         uint256 numTickets
//     ) external returns (uint256[] memory);

//     function createDrawingReceipts(
//         address to,
//         uint256 promotionID,
//         uint256 participantNumber,
//         address erc20TokenAddress,
//         uint256 numTickets
//     ) external returns (uint256[] memory);

//     function createSeedReceipt(
//         address to,
//         uint256 promotionID,
//         uint256 participantNumber,
//         address erc20TokenAddress,
//         bool seeded
//     ) external returns(uint256);

//     function createSeedReceipts(
//         address to,
//         uint256 promotionID,
//         uint256 startParticipantNumber,
//         address erc20TokenAddress,
//         bool seeded,
//         uint256 numTickets
//     ) external returns (uint256[] memory);

//     function nameDrawingWinner(uint256 tokenId, uint256 winningAmount) external; 

//     function rebateDrawingReceipts(
//         uint256[] memory tokenIds,
//         uint256 rebateAmount
//     ) external; 

//     function promotionToTokenIDs(uint256 promotionID, uint256 index) external view returns (uint256);
// }

// contract PromotionManager is VRFConsumerBaseV2  {
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
//         address erc20Token; 
//     }

//     struct Drawing {
//         uint256 maxSlots;
//         uint256 duration;
//         uint256 startTime;
//         uint256 price;
//         uint256 cohortSize;
//         uint256 rebateAmount;
//         uint256 custodyBalance; 
//         uint256 numParticipants; 
//         address owner; 
//         bool returnedCustody;
//         address erc20Token;
//     }

//     struct Seed {
//         uint256 seeds;
//         uint256 maxSlots;
//         uint256 price;
//         uint256 startTime;
//         uint256 duration;
//         uint256 numParticipants;
//         uint256 sharedAmount;
//         address owner;
//         uint256 earnedAmount;
//         address erc20Token;
//         uint256 custodyBalance;
//     }

//     struct VRFRequestContext {
//         uint256 drawingID;
//         uint256 cohort;
//         uint256 randomWord; 
//     }

//     enum PromotionType { Snowball, Drawing, Seed }

    
    

//     /* State Variables */
//     uint256 public promotionIDs = 1; 
//     uint256 public constant MINIMUM_DURATION = 900; 
//     uint256 public commission = 200; // basis points (divided by 10,000)
//     address payable public bank;
//     address public owner; 
//     address public receiptManagerAddress; 

//     mapping(uint256 => PromotionType) public promotionTypes;
//     mapping(uint256 => Snowball) public Snowballs;
//     mapping(uint256 => Drawing) public Drawings;
//     mapping(uint256 => Seed) public Seeds;

//     mapping(uint256=> mapping(uint256 => uint256)) drawingCohortsToVRFRequestID;
//     mapping(uint256 => VRFRequestContext) vrfRequestIDtoContext; 

//     mapping(address => mapping(address => bool)) approvedOperators;
//     mapping(address => uint256) earnedCommissions;
//     mapping(address => uint256) withdrawnCommissions; 

//     /* State Variables */
//     VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    
//     uint16 private constant REQUEST_CONFIRMATIONS = 3;
//     uint32 private immutable i_callbackGasLimit;
//     uint64 private immutable i_subscriptionId;
//     uint256 private s_lastTimeStamp;
//     bytes32 private immutable i_gasLane;

    

//     IReceiptManager public receiptManager; 
    

//     constructor(address vrfCoordinatorV2, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinatorV2) {
//         owner = msg.sender; // Set the owner to the contract deployer
//         bank = payable(owner);
//         i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
//         i_gasLane = gasLane; 
//         i_subscriptionId = subscriptionId;
//         i_callbackGasLimit = callbackGasLimit;
//     }

//     modifier onlyOwner() {
//         require(msg.sender == owner, "NotOwner");
//         _;
//     }

//     modifier onlyReceiptManager() {
//         require(msg.sender == receiptManagerAddress, "NotOwner");
//         _;
//     }

//     function setBank(address payable newBank) external onlyOwner {
//         bank = payable(newBank);
//     }

//     function setReceiptManager(address _receiptManagerAddress) external onlyOwner {
//         receiptManagerAddress = _receiptManagerAddress; 
//         receiptManager = IReceiptManager(_receiptManagerAddress); 
//     }

//     function withdrawCommissions(address erc20Token) external onlyOwner {
//         IERC20(erc20Token).transfer(bank, earnedCommissions[erc20Token] - withdrawnCommissions[erc20Token]);
//         withdrawnCommissions[erc20Token] = earnedCommissions[erc20Token]; 
//     }

//     function approveOperator(address approvedOperator) public {
//         require(approvedOperator != address(0), "Cannot approve zero address.");
//         approvedOperators[msg.sender][approvedOperator] = true; 
//         emit OperatorApproved(msg.sender, approvedOperator);
//     }

//     function removeOperator(address toRemove) public {
//         approvedOperators[msg.sender][toRemove] = false;
//         emit OperatorRemoved(msg.sender, toRemove);
//     }

//     function cancelPromotion(uint256 promotionID) public {
//         PromotionType promoType = promotionTypes[promotionID];
//         if (promoType == PromotionType.Snowball) {
//             Snowball storage snowball =Snowballs[promotionID]; 
//             if (msg.sender != snowball.owner && !approvedOperators[snowball.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//             if(snowball.startTime + snowball.duration > block.timestamp && snowball.numParticipants < snowball.maxSlots) {
//                 snowball.maxSlots = snowball.numParticipants;
//                 emit SnowballCancelled(promotionID, snowball.numParticipants);
//             }
//         }
//         else if (promoType == PromotionType.Drawing) {
//             Drawing storage drawing = Drawings[promotionID];
//             if (msg.sender != drawing.owner && !approvedOperators[drawing.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//             if (drawing.startTime + drawing.duration > block.timestamp && drawing.numParticipants < drawing.maxSlots) {
//                 uint256 numBuyersToCompensate = drawing.numParticipants % drawing.cohortSize;

//                 // Declare an array to hold IDs of receipts to compensate
//                 uint256[] memory receiptsToCompensate = new uint256[](numBuyersToCompensate);

//                 for (uint256 i = 0; i < numBuyersToCompensate; i++) {
//                     receiptsToCompensate[i] = receiptManager.promotionToTokenIDs(promotionID, drawing.numParticipants-1-i);
//                 }

//                 // Pass the array to the rebate function
//                 receiptManager.rebateDrawingReceipts(receiptsToCompensate, drawing.rebateAmount);
//                 emit DrawingCancelled(promotionID, numBuyersToCompensate);
//             }
//         }
//         else if(promoType == PromotionType.Seed) {
//             Seed storage seed = Seeds[promotionID];
//             if (msg.sender != seed.owner && !approvedOperators[seed.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//             if (seed.startTime + seed.duration > block.timestamp && seed.numParticipants < seed.maxSlots) {
//                 seed.maxSlots = seed.numParticipants;
//                 emit SeedCancelled(promotionID, seed.numParticipants);
//             }
//         }
//     }

//     function createDrawing(
//         uint256 _maxSlots,
//         uint256 _duration,
//         uint256 _price,
//         uint256 _cohortSize,
//         uint256 _rebateAmount,
//         address _owner,
//         address _erc20Token
//     ) public {
//         if (_cohortSize<=1 || _maxSlots % _cohortSize != 0  || _duration < MINIMUM_DURATION || _maxSlots <= 1) {
//             revert InvalidConfig();
//         }
//         if (msg.sender != _owner && !approvedOperators[_owner][msg.sender]) {
//             revert NotApproved(); 
//         }

//         // Initialize a new drawing contract and store it in storage
//         Drawing storage drawing = Drawings[promotionIDs];
//         drawing.maxSlots = _maxSlots;
//         drawing.duration = _duration;
//         drawing.owner = payable(_owner);
//         drawing.startTime = block.timestamp;
//         drawing.price = _price;
//         drawing.cohortSize = _cohortSize;
//         drawing.rebateAmount = _rebateAmount;
//         drawing.erc20Token = _erc20Token; 

//         IERC20(_erc20Token).approve(receiptManagerAddress, type(uint256).max);
//         emit DrawingCreated(_owner, promotionIDs, _erc20Token, _maxSlots, _duration, block.timestamp, _price, _cohortSize, _rebateAmount); 
//         promotionTypes[promotionIDs] = PromotionType.Drawing;
//         promotionIDs+=1; 
//     }

//     function joinDrawing(uint256 drawingID, uint256 numTickets) public {
//         Drawing storage drawing = Drawings[drawingID];

//         // Check if the promotion is expired or slots are full
//         if (drawing.numParticipants + numTickets > drawing.maxSlots || 
//             drawing.duration + drawing.startTime < block.timestamp) {
//             revert Promotion_Expired();
//         }

//         // Calculate amounts
//         uint256 totalRebate = drawing.rebateAmount * numTickets;
//         uint256 totalSellerAmount = (drawing.price - drawing.rebateAmount) * numTickets;
//         uint256 commissionAmount = calculateCommission(totalSellerAmount);
//         uint256 totalAmount = totalRebate + totalSellerAmount;

//         // Transfer funds
//         IERC20(drawing.erc20Token).transferFrom(msg.sender, address(this), totalAmount);
//         IERC20(drawing.erc20Token).transfer(drawing.owner, totalSellerAmount - commissionAmount);

//         // Update balances
//         drawing.custodyBalance += totalRebate;
//         earnedCommissions[drawing.erc20Token] += commissionAmount;

//         // Create DrawingReceipts in a batch
//         uint256[] memory receiptIDs = receiptManager.createDrawingReceipts(
//             msg.sender, 
//             drawingID, 
//             drawing.numParticipants + 1, 
//             drawing.erc20Token, 
//             numTickets
//         );

//         // Emit event for the first receipt
//         emit DrawingJoined(
//             msg.sender, 
//             drawingID, 
//             drawing.numParticipants + 1, 
//             receiptIDs[0], 
//             numTickets
//         );

//         // Update the number of participants
//         drawing.numParticipants += numTickets;
//     }

//     function drawingEligibility(uint256 drawingID, uint256 cohort) public view returns (bool) {
//         Drawing storage drawing = Drawings[drawingID];
//         bool eligibility = true; 
//         if( drawing.numParticipants < drawing.cohortSize*(1+cohort) ||
//         vrfRequestIDtoContext[drawingCohortsToVRFRequestID[drawingID][cohort]].drawingID == drawingID) {
//             eligibility=false; 
//         }
//         return eligibility; 
//     } 

//     function initiateDrawing(uint256 _drawingID, uint256 _cohort) public  {
//         require(drawingEligibility(_drawingID, _cohort), "Ineligible");         
//         uint256 requestId = i_vrfCoordinator.requestRandomWords(
//             i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, 1
//         ); //check this, change 1 to something else
//         VRFRequestContext storage context = vrfRequestIDtoContext[requestId];
//         context.drawingID = _drawingID;
//         context.cohort = _cohort; 
//         drawingCohortsToVRFRequestID[_drawingID][_cohort] = requestId; 
//         //check if the above line should be emitted rather than saved
//         emit RaffleInitiated(_drawingID, requestId , msg.sender,_cohort); 
//     }

//     //Should be external? add override. can it calldata?
//     function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override{
//         VRFRequestContext storage context = vrfRequestIDtoContext[requestId];
//         Drawing storage drawing = Drawings[context.drawingID];

//         //Store random word
//         context.randomWord = randomWords[0]; 

//         //Identify the winner. Check the winning participant number is winnerIndex +1
//         uint256 winnerIndex = (context.cohort*drawing.cohortSize)  + (randomWords[0]%drawing.cohortSize);
        
//         uint256 winningReceiptID = receiptManager.promotionToTokenIDs(context.drawingID, winnerIndex); 
//         uint256 winningAmount = drawing.rebateAmount*drawing.cohortSize;
//         receiptManager.nameDrawingWinner(winningReceiptID, winningAmount);
//         emit RaffleWinner(context.drawingID, context.cohort, winningReceiptID, winnerIndex+1, winningAmount); 
//     }

//     function retrieveExcessDrawingCustody(uint256 drawingID) public {
//         Drawing storage drawing = Drawings[drawingID];
        
//         // Ensure that the drawing has either ended or reached max participants
//         bool isExpiredOrFull = block.timestamp > drawing.duration + drawing.startTime || drawing.maxSlots == drawing.numParticipants;
        
//         // Check if the custody has already been returned
//         require(isExpiredOrFull, "Ineligible");
//         require(!drawing.returnedCustody, "Already Returned");

//         // Calculate excess custody based on remaining participants after filling cohorts
//         uint256 excessCustody = (drawing.numParticipants % drawing.cohortSize) * drawing.rebateAmount;
        
//         // Reduce custody balance by the excess custody amount
//         drawing.custodyBalance -= excessCustody;
        
//         // Calculate and deduct commission
//         uint256 commissionAmount = calculateCommission(excessCustody);
//         earnedCommissions[drawing.erc20Token] += commissionAmount;

        
//         // Pay the owner the remaining amount after deducting the commission
//         IERC20(drawing.erc20Token).transfer(drawing.owner, excessCustody - commissionAmount); 
        
//         // Mark custody as returned
//         drawing.returnedCustody = true;

//         //Emit the event
//         emit DrawingCustodyRedeemed(drawingID, excessCustody); 

//     }
//     function reduceDrawingCustodyBalance(uint256 drawingID, uint256 reductionAmount) onlyReceiptManager external {
//         Drawings[drawingID].custodyBalance -= reductionAmount; 
//     }

//     //can the arrays be calldata?
//     function createSnowball(
//         uint256 _maxSlots,
//         uint256 _duration,
//         uint256[] memory _cohortPrices,
//         uint256[] memory _thresholds,
//         address _owner,
//         address _erc20Token
//     ) public {
//         if (_cohortPrices.length -1 != _thresholds.length || 
//             _cohortPrices.length < 2 || 
//             _cohortPrices.length > 5 || 
//             _thresholds[0] <=1 || 
//             _thresholds[_thresholds.length - 1]> _maxSlots || 
//             _duration < MINIMUM_DURATION ) {
//             revert InvalidConfig(); 
//         }

//         // Check that _cohortPrices is strictly decreasing, and all values are nonzero
//         for (uint256 i = 0; i < _cohortPrices.length; i++) {
//             if (_cohortPrices[i] == 0) {
//                 revert InvalidConfig(); // Reject zero values in _cohortPrices
//             }
//             if (i > 0) {
//                 if (_cohortPrices[i] >= _cohortPrices[i - 1]) {
//                     revert InvalidConfig(); // Ensure strictly decreasing order
//                 }
//             }
//         }

//         // Check that _thresholds is strictly increasing
//         if (_thresholds.length > 1) {
//             for (uint256 i = 1; i < _thresholds.length; i++) {
//                 if (_thresholds[i] <= _thresholds[i - 1]) {
//                     revert InvalidConfig(); // Ensure strictly increasing order
//                 }
//             }
//         }

//         if (msg.sender != _owner && !approvedOperators[_owner][msg.sender]) {
//             revert NotApproved(); 
//         }

//         // Initialize a new snowball contract and store it in storage
//         Snowball storage snowball = Snowballs[promotionIDs];
//         promotionTypes[promotionIDs] = PromotionType.Snowball;
//         snowball.maxSlots = _maxSlots;
//         snowball.duration = _duration;
//         snowball.thresholds = _thresholds;
//         snowball.owner = payable(_owner);
//         snowball.startTime = block.timestamp;
//         snowball.cohortPrices = _cohortPrices;
//         snowball.erc20Token = _erc20Token;
//         IERC20(_erc20Token).approve(receiptManagerAddress, type(uint256).max);


//         emit SnowballCreated(_owner, promotionIDs, _erc20Token, _maxSlots, _duration, block.timestamp, _thresholds, _cohortPrices);
//         promotionIDs += 1; 
//     }


//     function getSnowballPrice(uint256 snowballID) public view returns(uint256) {
//         Snowball memory snowball = Snowballs[snowballID]; 
//         if(snowball.maxSlots == snowball.numParticipants) {
//             /*
//             In this case, the price must be that of the last cohort. This edge 
//             check is needed as cancelling a Snowball early sets maxSlots to numParticipants, 
//             thus looping through thresholds will not produce the intended result of 
//             returning the lowest possible price. 
//             */
//             return snowball.cohortPrices[snowball.cohortPrices.length-1]; 
//         }
//         uint256 updatedPrice = snowball.cohortPrices[0]; //Set to price of first cohort
//         for (uint256 i = 0; i < snowball.thresholds.length; i++) {
//             if(snowball.numParticipants >= snowball.thresholds[i]) {
//                 updatedPrice = snowball.cohortPrices[i+1];
//             }
//             else{
//                 break;
//             } 
//         }
//         return updatedPrice; 
//     }

//     function getUpdatedSnowballPrice(uint256[] memory cohortPrices, uint256[] memory thresholds, uint256 updatedParticipants) public pure returns(uint256) {
//         uint256 updatedPrice =cohortPrices[0]; //Set to price of first cohort
//         for (uint256 i = 0; i < thresholds.length; i++) {
//             if(updatedParticipants >= thresholds[i]) {
//                 updatedPrice = cohortPrices[i+1];
//             }
//             else{
//                 break;
//             } 
//         }
//         return updatedPrice; 
//     }

//     function joinSnowball(uint256 snowballID, uint256 numTickets) public {
//         Snowball storage snowball = Snowballs[snowballID]; // Use storage reference to minimize repeated storage reads

//         // Check for expiration or slot limits
//         require(block.timestamp <= snowball.startTime + snowball.duration, "Expired");
//         require(snowball.numParticipants + numTickets <= snowball.maxSlots, "Full");

//         // Calculate prices and custody amount
//         uint256 newPrice = getUpdatedSnowballPrice(
//             snowball.cohortPrices, 
//             snowball.thresholds, 
//             snowball.numParticipants + numTickets
//         );
//         uint256 minPrice = snowball.cohortPrices[snowball.cohortPrices.length - 1];
//         uint256 totalCustodyAmount = (newPrice - minPrice) * numTickets;

//         // Update custody balance if needed
//         if (totalCustodyAmount > 0) {
//             snowball.custodyBalance += totalCustodyAmount;
//         }

//         // Calculate commission
//         uint256 commissionAmount = calculateCommission(numTickets * minPrice);

//         // Perform a single transfer for efficiency
//         IERC20(snowball.erc20Token).transferFrom(msg.sender, address(this), newPrice*numTickets);

//         // Update commissions and pay the owner
//         earnedCommissions[snowball.erc20Token] += commissionAmount;
//         uint256 ownerPayment = numTickets * minPrice - commissionAmount;
//         IERC20(snowball.erc20Token).transfer(snowball.owner, ownerPayment);

//         // Mint receipts in batch
//         uint256[] memory receiptIDs = receiptManager.createSnowballReceipts(
//             msg.sender, 
//             snowballID, 
//             snowball.numParticipants + 1, 
//             newPrice, 
//             snowball.erc20Token, 
//             numTickets
//         );

//         // Emit event with the first receipt ID
//         emit SnowballJoined(
//             msg.sender, 
//             snowballID, 
//             snowball.numParticipants + 1, 
//             receiptIDs[0], 
//             newPrice, 
//             numTickets
//         );

//         // Update participants count
//         snowball.numParticipants += numTickets;
//     }

//     function retrieveExcessSnowballCustody(uint256 snowballID) public {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         //Check that the snowball has ended
//         require((block.timestamp > snowball.duration + snowball.startTime || snowball.maxSlots == snowball.numParticipants) && !snowball.returnedCustody, "Ineligible");
//         // Caculate excess custody
//         uint256 excessCustody = calculateExcessSnowballCustody(snowballID);        
//         //Return excess if the snowball has ended
//         uint256 commissionAmount = calculateCommission(excessCustody); //Commission is on all proceeds to sellers. 
//         earnedCommissions[snowball.erc20Token] += commissionAmount;
//         IERC20(snowball.erc20Token).transfer(snowball.owner, excessCustody-commissionAmount); 
//         snowball.custodyBalance -=excessCustody; 
//         snowball.returnedCustody = true; 
//         emit SnowballCustodyRedeemed(snowballID, excessCustody);
//     }
    

//     function calculateExcessSnowballCustody(uint snowballID) public view returns(uint256) {
//         uint256 currentPrice = getSnowballPrice(snowballID);
//         uint256 excessCustody = (currentPrice-Snowballs[snowballID].cohortPrices[Snowballs[snowballID].cohortPrices.length-1]) * Snowballs[snowballID].numParticipants;
//         return  excessCustody;
//     }

//     //Calculates the commissions given the non-custody amount
//     function calculateCommission(uint256 totalAmount) internal view returns (uint256) { //should be internal
//         uint256 commissionAmount = totalAmount *commission/10000; 
//         return (commissionAmount);
//     }


    
//     function reduceSnowballCustodyBalance(uint256 snowballID, uint256 reductionAmount) onlyReceiptManager external {
//         Snowballs[snowballID].custodyBalance -= reductionAmount;
//     }
//     function isOwner(uint256 promotionID, address possibleOwner) external view returns (bool) {
//         PromotionType promoType = promotionTypes[promotionID];
//         if (promoType == PromotionType.Snowball) {
//             return (Snowballs[promotionID].owner == possibleOwner);
//         } else if (promoType == PromotionType.Seed) {
//             return (Seeds[promotionID].owner == possibleOwner);
//         } else {
//             return (Drawings[promotionID].owner == possibleOwner);
//         }
//     }



//     function createSeed(uint256 _seeds, uint256 _maxSlots, uint256 _price, uint256 _duration, uint256 _sharedAmount, address _owner, address _erc20Token) public {
//         if (_seeds >= _maxSlots || _sharedAmount >= _price || _duration < MINIMUM_DURATION || _maxSlots <= 1) {
//             revert InvalidConfig();
//         }
//         if (msg.sender != _owner && !approvedOperators[_owner][msg.sender]) {
//             revert NotApproved(); 
//         }

//         // Initialize a new seed contract and store it in storage
//         Seed storage seed = Seeds[promotionIDs];
//         promotionTypes[promotionIDs] = PromotionType.Seed;
//         seed.seeds = _seeds;
//         seed.maxSlots = _maxSlots;
//         seed.price = _price;
//         seed.startTime = block.timestamp;
//         seed.duration = _duration;
//         seed.sharedAmount = _sharedAmount;
//         seed.erc20Token = _erc20Token; 
//         seed.owner = _owner; 
//         IERC20(_erc20Token).approve(receiptManagerAddress, type(uint256).max);

//         emit SeedCreated(_owner, promotionIDs, _erc20Token, _seeds, _maxSlots, _sharedAmount, _duration, block.timestamp);
//         promotionIDs += 1; 
//     }

//     function joinSeed(uint256 seedID, uint256 numTickets) public {
//         Seed storage seed = Seeds[seedID];
//         require(
//             seed.duration + seed.startTime >= block.timestamp && 
//             seed.numParticipants + numTickets <= seed.maxSlots, 
//             "Full"
//         );

//         // Calculate seeded and unseeded participants
//         uint256 seededParticipants = 0;
//         uint256 unseededParticipants = numTickets;

//         if (seed.numParticipants < seed.seeds) {
//             uint256 availableSeededSlots = seed.seeds - seed.numParticipants;
//             seededParticipants = availableSeededSlots < numTickets ? availableSeededSlots : numTickets;
//             unseededParticipants = numTickets - seededParticipants;
//         }

//         uint256 firstParticipant = seed.numParticipants + 1;

//         // Handle seeded receipts and emit event
//         uint256[] memory seededReceiptIDs;
//         if (seededParticipants > 0) {
//             seededReceiptIDs = receiptManager.createSeedReceipts(
//                 msg.sender, 
//                 seedID, 
//                 firstParticipant, 
//                 seed.erc20Token, 
//                 true, 
//                 seededParticipants
//             );
//             emit SeedJoined(msg.sender, seedID, firstParticipant, seededReceiptIDs[0], true, seededParticipants);
//         }

//         // Handle unseeded receipts and emit event
//         uint256[] memory unseededReceiptIDs;
//         if (unseededParticipants > 0) {
//             uint256 firstUnseededParticipant = firstParticipant + seededParticipants;
//             unseededReceiptIDs = receiptManager.createSeedReceipts(
//                 msg.sender, 
//                 seedID, 
//                 firstUnseededParticipant, 
//                 seed.erc20Token, 
//                 false, 
//                 unseededParticipants
//             );
//             emit SeedJoined(msg.sender, seedID, firstUnseededParticipant, unseededReceiptIDs[0], false, unseededParticipants);
//         }

//         // Update participant count
//         seed.numParticipants += numTickets;

//         // Batch commission and transfer calculations
//         uint256 sharedAmount = seed.sharedAmount * unseededParticipants;
//         uint256 amountToSeller = 
//             (seededParticipants * seed.price) + 
//             (unseededParticipants * (seed.price - seed.sharedAmount));

//         uint256 commissionOnShared = calculateCommission(sharedAmount);
//         uint256 commissionOnSeller = calculateCommission(amountToSeller);

//         uint256 totalAmount = sharedAmount + amountToSeller;
//         uint256 totalCommission = commissionOnShared + commissionOnSeller;

//         // Update balances
//         seed.earnedAmount += sharedAmount - commissionOnShared;
//         seed.custodyBalance += sharedAmount - commissionOnShared;
//         earnedCommissions[seed.erc20Token] += totalCommission;

//         // Single transferFrom call for the total amount
//         IERC20(seed.erc20Token).transferFrom(
//             msg.sender, 
//             address(this), 
//             totalAmount
//         );

//         // Transfer seller's share
//         IERC20(seed.erc20Token).transfer(
//             seed.owner, 
//             amountToSeller - commissionOnSeller
//         );
//     }
    
    
//     function seedRedeemableAmount(uint256 seedID) public view returns (uint256) {
//         Seed storage seed = Seeds[seedID];
//         return seed.earnedAmount/seed.seeds; 
//     }

//     function reduceSeedCustodyBalance(uint256 seedID, uint256 reductionAmount) onlyReceiptManager external {
//         Seeds[seedID].custodyBalance -= reductionAmount;
//     }

//     function getPromotionOwner(uint256 promotionID) public view returns (address) {
//         if(promotionTypes[promotionID] == PromotionType.Snowball) {
//             return Snowballs[promotionID].owner;
//         } 
//         else if(promotionTypes[promotionID] == PromotionType.Drawing) {
//             return Drawings[promotionID].owner;
//         } 
//         else if(promotionTypes[promotionID] == PromotionType.Seed) {
//             return Seeds[promotionID].owner;
//         } 

//     }

// }
