// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// event SnowballReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 redeemedAmount); 
// event DrawingReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 redeemedAmount); 
// event SeedReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 redeemedAmount); 
// event DrawingReceiptsMinted(address indexed joiner, uint256 indexed promotionID, uint256 indexed firstParticipantNumber, uint256 firstTokenID, uint256 numTickets);
// event SnowballReceiptsMinted(address indexed joiner, uint256 indexed promotionID, uint256 firstParticipantNumber, uint256 firstTokenID, uint256 pricePaid, uint256 numTickets);
// event SeedReceiptsMinted(address indexed joiner, uint256 promotionID, uint256 firstParticipantNumber, uint256  firstTokenID, bool seeded, uint256 numTickets);
// event RaffleWinner(uint256 indexed promotionID, uint256 cohort, uint256 tokenID, uint256 participantNumber, uint256 prize); 
// event RaffleInitiated(uint256 indexed promotionID, uint256 indexed vrfRequestID, address indexed initiator, uint256 cohort); //initiators should be reimbursed more in potential air-drops

// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../interfaces/IPromotionManager.sol";
// import "../interfaces/IReceiptManager.sol";

// contract ReceiptLogger is VRFConsumerBaseV2 {
//     struct SnowballReceipt {
//         uint256 promotionID;
//         uint256 participantNumber;
//         uint256 effectivePricePaid;
//         address erc20TokenAddress;
//     }

//     struct DrawingReceipt {
//         uint256 promotionID;
//         uint256 participantNumber;
//         uint256 redeemableAmount;
//         bool winner;
//         address erc20TokenAddress;
//     }

//     struct SeedReceipt {
//         uint256 promotionID;
//         uint256 participantNumber;
//         uint256 redeemedAmount;
//         bool seeded;
//         address erc20TokenAddress;
//     }

//     struct VRFRequestContext {
//         uint256 drawingID;
//         uint256 cohort;
//         uint256 randomWord; 
//     }

//     // Enum to keep track of the type of receipt
//     enum ReceiptType {
//         Snowball,
//         Drawing,
//         Seed
//     }

//     address promotionManagerAddress;
//     address owner;
//     address bank;
//     mapping(uint256 => SnowballReceipt) public snowballReceipts;
//     mapping(uint256 => DrawingReceipt) public drawingReceipts;
//     mapping(uint256 => SeedReceipt) public seedReceipts;
//     mapping(uint256 => uint256[]) public promotionToTokenIDs;
//     mapping(uint256 => VRFRequestContext) vrfRequestIDtoContext; 
//     mapping(uint256=> mapping(uint256 => uint256)) drawingCohortsToVRFRequestID;

//     // Mapping to track which type of receipt corresponds to each token ID
//     mapping(uint256 => ReceiptType) public receiptTypes;

//     IPromotionManager public promotionManager;
//     IReceiptManager public receiptManager; 

//     /* State Variables */
//     VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

//     uint16 private constant REQUEST_CONFIRMATIONS = 3;
//     uint32 private immutable i_callbackGasLimit;
//     uint64 private immutable i_subscriptionId;
//     uint256 private s_lastTimeStamp;
//     bytes32 private immutable i_gasLane;

//     modifier onlyPromoManager() {
//         require(msg.sender == promotionManagerAddress, "Not Authorized");
//         _;
//     }

//     constructor(
//         address vrfCoordinatorV2,
//         address _receiptManagerAddress,
//         bytes32 gasLane,
//         uint64 subscriptionId,
//         uint32 callbackGasLimit
//     ) VRFConsumerBaseV2(vrfCoordinatorV2) {
//         owner = msg.sender; // Set the owner to the contract deployer
//         bank = payable(owner);
//         i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
//         i_gasLane = gasLane;
//         i_subscriptionId = subscriptionId;
//         i_callbackGasLimit = callbackGasLimit;
//         receiptManager = IReceiptManager(_receiptManagerAddress); 
//     }

//     // Function to mint multiple Snowball Receipts in a batch
//     function createSnowballReceipts(
//         address to, 
//         uint256 promotionID,
//         uint256 startParticipantNumber,
//         uint256 effectivePricePaid,
//         address erc20TokenAddress,
//         uint256 numTickets,
//         uint256 receiptTotalSupply
//     ) external onlyPromoManager {
//         require(numTickets > 0, "Number of tickets must be greater than zero");
//         uint256 initialID = receiptTotalSupply +1 ; 
//         for (uint256 i = 0; i < numTickets; i++) {
//             // Create a new SnowballReceipt
//             snowballReceipts[initialID+i] = SnowballReceipt(
//                 promotionID,
//                 startParticipantNumber + i, // Increment the participant number for each ticket
//                 effectivePricePaid,
//                 erc20TokenAddress
//             );

//             // Set the receipt type
//             receiptTypes[initialID +i] = ReceiptType.Snowball;

//             // Map the minted receipt to the promotion
//             promotionToTokenIDs[promotionID].push(initialID +i);
//         }

//         // Emit event with the first receipt ID
//         emit SnowballReceiptsMinted(
//             to, 
//             promotionID, 
//             startParticipantNumber, 
//             initialID, 
//             effectivePricePaid, 
//             numTickets
//         );
//     }

//     function createDrawingReceipts(
//         address to, 
//         uint256 promotionID,
//         uint256 startParticipantNumber,
//         address erc20TokenAddress,
//         uint256 numTickets,
//         uint256 receiptTotalSupply
//     ) external onlyPromoManager {
//         require(numTickets > 0, "Inv");
//         uint256 initialID = receiptTotalSupply +1; 
//         for (uint256 i = 0; i < numTickets; i++) {
//             // Create and store the DrawingReceipt
//             drawingReceipts[initialID+i] = DrawingReceipt(
//                 promotionID,
//                 startParticipantNumber + i, // Increment participant number for each ticket
//                 0,
//                 false,
//                 erc20TokenAddress
//             );

//             // Set receipt type
//             receiptTypes[initialID+i] = ReceiptType.Drawing;

//             // Map receipt ID to promotion
//             promotionToTokenIDs[promotionID].push(initialID+i);
//         }
//         emit DrawingReceiptsMinted(
//             to, 
//             promotionID, 
//             startParticipantNumber, 
//             initialID, 
//             numTickets
//         );
//     }

//     function createSeedReceipts(
//         address to, 
//         uint256 promotionID,
//         uint256 startParticipantNumber,
//         address erc20TokenAddress,
//         bool seeded,
//         uint256 numTickets,
//         uint256 receiptTotalSupply
//     ) external onlyPromoManager {
//         require(numTickets > 0, "Inv");
//         uint256 initialID = receiptTotalSupply + 1; // Start ID for this batch
//         for (uint256 i = 0; i < numTickets; i++) {
//             // Create a new SeedReceipt for each ticket
//             seedReceipts[initialID + i] = SeedReceipt(
//                 promotionID,
//                 startParticipantNumber + i, // Increment the participant number for each ticket
//                 0, // Initialize to 0
//                 seeded,
//                 erc20TokenAddress
//             );

//             // Set the receipt type
//             receiptTypes[initialID + i] = ReceiptType.Seed;

//             // Map the minted receipt ID to the promotion
//             promotionToTokenIDs[promotionID].push(initialID + i);
//         }
//         emit SeedReceiptsMinted(to, promotionID, startParticipantNumber, initialID, seeded, numTickets);
//     }

//     // Must only batch receipts with the same payment tokens
//     function redeemReceipts(uint256[] calldata tokenIDs) public {
//         //Initialize variables
//         uint256 totalRedeemable;
//         address erc20Token;
//         //Get address of erc20 token of first receipt
//         if (receiptTypes[tokenIDs[0]] == ReceiptType.Snowball) {
//             erc20Token = snowballReceipts[tokenIDs[0]].erc20TokenAddress;
//         } else if (receiptTypes[tokenIDs[0]] == ReceiptType.Drawing) {
//             erc20Token = drawingReceipts[tokenIDs[0]].erc20TokenAddress;
//         } else if (receiptTypes[tokenIDs[0]] == ReceiptType.Seed) {
//             erc20Token = seedReceipts[tokenIDs[0]].erc20TokenAddress;
//         }

//         for (uint256 i = 0; i < tokenIDs.length; i++) {
//             uint256 tokenId = tokenIDs[i];
//             ReceiptType receiptType = receiptTypes[tokenId];
//             if (receiptType == ReceiptType.Snowball) {
//                 require((receiptManager.ownerOf(tokenId) == msg.sender), "Not owned");
//                 if (snowballReceipts[tokenId].erc20TokenAddress != erc20Token) {
//                     revert("Different token type");
//                 }
//                 uint256 currentPrice = promotionManager.getSnowballPrice(
//                     snowballReceipts[tokenId].promotionID
//                 );

//                 uint256 redeemable = snowballReceipts[tokenId]
//                     .effectivePricePaid - currentPrice;
//                 emit SnowballReceiptRedeemed(tokenId, snowballReceipts[tokenId].promotionID, redeemable); 
//                 promotionManager.reduceSnowballCustodyBalance(
//                     snowballReceipts[tokenId].promotionID,
//                     redeemable
//                 );

//                 snowballReceipts[tokenId].effectivePricePaid = currentPrice;

//                 totalRedeemable += redeemable;
//             } else if (receiptType == ReceiptType.Drawing) {
//                 require((receiptManager.ownerOf(tokenId) == msg.sender), "Not owned");
//                 if (drawingReceipts[tokenId].erc20TokenAddress != erc20Token) {
//                     revert("Different token type");
//                 }
//                 DrawingReceipt storage drawingReceipt = drawingReceipts[
//                     tokenId
//                 ];
//                 uint256 redeemableAmount = drawingReceipt.redeemableAmount;

//                 if (redeemableAmount > 0) {
//                     promotionManager.reduceDrawingCustodyBalance(
//                         drawingReceipt.promotionID,
//                         redeemableAmount
//                     );
//                     emit DrawingReceiptRedeemed(tokenId, drawingReceipt.promotionID, redeemableAmount); 
//                     drawingReceipt.redeemableAmount = 0;
//                     totalRedeemable += redeemableAmount;
//                 }
//             } else if (receiptType == ReceiptType.Seed) {
//                 SeedReceipt storage seedReceipt = seedReceipts[tokenId];
//                 if (seedReceipt.erc20TokenAddress != erc20Token) {
//                     revert("Different token type");
//                 }
//                 uint256 redeemableAmount = promotionManager
//                     .seedRedeemableAmount(seedReceipt.promotionID);
//                 if (redeemableAmount > seedReceipt.redeemedAmount) {
//                     totalRedeemable += (redeemableAmount -
//                         seedReceipt.redeemedAmount);
//                     promotionManager.reduceSeedCustodyBalance(
//                         seedReceipt.promotionID,
//                         (redeemableAmount - seedReceipt.redeemedAmount)
//                     );
//                     seedReceipt.redeemedAmount = redeemableAmount;
//                     emit SeedReceiptRedeemed(tokenId, seedReceipt.promotionID, redeemableAmount); 
//                 }
//             } 
//         }

//         // Perform a single transfer for the total redeemable amount
//         if (totalRedeemable > 0) {
//             IERC20(erc20Token).transferFrom(
//                 promotionManagerAddress,
//                 msg.sender,
//                 totalRedeemable
//             );
//         }
//     }

//     function nameDrawingWinner(
//         uint256 tokenId,
//         uint256 winningAmount
//     ) internal {
//         DrawingReceipt storage drawingReceipt = drawingReceipts[tokenId];
//         drawingReceipt.redeemableAmount = winningAmount;
//         drawingReceipt.winner = true;
//     }

//     function rebateDrawingReceipts(
//         uint256[] memory tokenIds,
//         uint256 rebateAmount
//     ) external onlyPromoManager {
//         for (uint256 i = 0; i < tokenIds.length; i++) {
//             DrawingReceipt storage drawingReceipt = drawingReceipts[
//                 tokenIds[i]
//             ];
//             drawingReceipt.redeemableAmount = rebateAmount;
//         }
//     }
    
//     function initiateDrawing(uint256 _drawingID, uint256 _cohort) public  {
//         require(promotionManager.drawingEligibility(_drawingID, _cohort) && vrfRequestIDtoContext[drawingCohortsToVRFRequestID[_drawingID][_cohort]].drawingID !=0, "Ineligible");         
//         uint256 requestId = i_vrfCoordinator.requestRandomWords(
//             i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, 1
//         ); //check this, change 1 to something else
//         vrfRequestIDtoContext[requestId].drawingID = _drawingID;
//         vrfRequestIDtoContext[requestId].cohort = _cohort; 
//         drawingCohortsToVRFRequestID[_drawingID][_cohort] = requestId; 
//         //check if the above line should be emitted rather than saved
//         emit RaffleInitiated(_drawingID, requestId , msg.sender,_cohort); 
//     }    

//     function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override{
//         VRFRequestContext memory context = vrfRequestIDtoContext[requestId];
//         (uint256 cohortSize, uint256 rebateAmount) = promotionManager.getDrawingCohortSizeAndRebate(context.drawingID);

//         //Store random word
//         vrfRequestIDtoContext[requestId].randomWord = randomWords[0]; 

//         //Identify the winner. Check the winning participant number is winnerIndex +1
//         uint256 winnerIndex = (context.cohort*cohortSize)  + (randomWords[0]%cohortSize);
        
//         uint256 winningReceiptID = promotionToTokenIDs[context.drawingID][winnerIndex]; 
//         uint256 winningAmount = rebateAmount*cohortSize;
//         nameDrawingWinner(winningReceiptID, winningAmount);
//         emit RaffleWinner(context.drawingID, context.cohort, winningReceiptID, winnerIndex+1, winningAmount); 
//     }

//     function getTokenID(uint256 promotionID,uint256 index) external view returns (uint256) {
//         return promotionToTokenIDs[promotionID][index];
//     }

//     function getTokenIDsInRange(
//         uint256 promotionID,
//         uint256 startIndex,
//         uint256 endIndex
//     ) external view returns (uint256[] memory) {
//         require(endIndex >= startIndex, "Invalid index range");
//         uint256 arrayLength = promotionToTokenIDs[promotionID].length;
//         require(endIndex < arrayLength, "End index out of bounds");

//         uint256 rangeLength = endIndex - startIndex + 1;
//         uint256[] memory result = new uint256[](rangeLength);

//         for (uint256 i = 0; i < rangeLength; i++) {
//             result[i] = promotionToTokenIDs[promotionID][startIndex + i];
//         }

//         return result;
//     }

// }
