// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error Promotion_Expired();
// error InvalidConfig(); 
// error NotApproved();

// event DrawingCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 maxSlots, uint256 endTime, uint256 price, uint256 cohortSize, uint256 rebateAmount, bool mintsNFTs);
// event DrawingCustodyRedeemed(uint256 indexed promotionID, uint256 redeemedAmount); 
// event DrawingCancelled(uint256 indexed promotionID, uint256 numberOfParticipants);
// event DrawingReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 redeemedAmount); 
// event DrawingReceiptsMinted(address indexed joiner, uint256 indexed promotionID, uint256 indexed firstParticipantNumber, uint256 firstTokenID, uint256 numTickets);
// event RaffleWinner(uint256 indexed promotionID, uint256 cohort, uint256 tokenID, uint256 participantNumber, uint256 prize,  uint256 randomWord); 
// event RafflesInitiated(uint64[] promotionIDs, uint256 indexed vrfRequestID, address indexed initiator, uint16[] cohorts); //initiators should be reimbursed more in potential air-drops

// import "hardhat/console.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./PromotionManagerv9.sol";

// contract DrawingManager is VRFConsumerBaseV2, PromotionManager {

//     struct Drawing {
//         uint256 endTime;  
//         uint256 price;  
//         uint256 rebateAmount;    
//         address owner;          
//         bool returnedCustody;    
//         bool mintsNFTs;        
//         uint16 maxSlots;        
//         uint16 cohortSize;      
//         address erc20Token;      
//     }

//     struct DrawingReceipt {
//         uint256 drawingID;
//         uint256 redeemableAmount;
//     }

//     struct VRFRequestContext {
//         uint64[] drawingIDArray; 
//         uint16[] cohorts;
//         uint256[] randomWords; 
//     }

//     uint256 public drawingIDs = 200;// type(uint256).max / 10 * 2 + 1;
//     uint256 public constant MINIMUM_DURATION = 900; 


//     mapping(uint256 => DrawingReceipt) public DrawingReceipts;
//     mapping(uint256 => Drawing) public Drawings;
//     mapping(uint256 => VRFRequestContext) vrfRequestIDtoContext; 
//     mapping(uint256=> mapping(uint256 => bool)) raffleInitiatedBool;

//     /* State Variables */
//     VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

//     uint16 private constant REQUEST_CONFIRMATIONS = 3;
//     uint32 private immutable i_callbackGasLimit;
//     uint64 private immutable i_subscriptionId;
//     uint256 private s_lastTimeStamp;
//     bytes32 private immutable i_gasLane;

//     constructor(
//         address vrfCoordinatorV2,
//         address _receiptManagerAddress,
//         address _promotionsManagerAddress, 
//         bytes32 gasLane,
//         uint64 subscriptionId,
//         uint32 callbackGasLimit
//     ) VRFConsumerBaseV2(vrfCoordinatorV2) { 
//         contractOwner = msg.sender; // Set the owner to the contract deployer
//         receiptManagerAddress = _receiptManagerAddress;  
//         receiptManager = IReceiptManager(_receiptManagerAddress);
//         promotionsManagerAddress = _promotionsManagerAddress;  
//         promotionsManager = IPromotionsManager(_promotionsManagerAddress);
//         i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
//         i_gasLane = gasLane;
//         i_subscriptionId = subscriptionId;
//         i_callbackGasLimit = callbackGasLimit;
//     }

//     function createDrawing(
//         uint16 _maxSlots,
//         uint256 _duration,
//         uint256 _price,
//         uint16 _cohortSize,
//         uint256 _rebateAmount,
//         address _owner,
//         address _erc20Token, 
//         bool _mintsNFTs
//     ) public onlyApprovedOperators(_owner) {
//         if (_cohortSize<=1 || _maxSlots % _cohortSize != 0  || _duration < MINIMUM_DURATION || _maxSlots <= 1 || _rebateAmount >= _price*_cohortSize) {
//             revert InvalidConfig();
//         }

//         // Initialize a new drawing contract and store it in storage
//         Drawing storage drawing = Drawings[drawingIDs];
//         drawing.maxSlots = _maxSlots;
//         drawing.owner = payable(_owner);
//         drawing.endTime = block.timestamp + _duration;
//         drawing.price = _price;
//         drawing.cohortSize = _cohortSize;
//         drawing.rebateAmount = _rebateAmount;
//         drawing.erc20Token = _erc20Token; 
//         drawing.mintsNFTs = _mintsNFTs;

//         emit DrawingCreated(_owner, drawingIDs, _erc20Token, _maxSlots, _duration + block.timestamp, _price, _cohortSize, _rebateAmount, _mintsNFTs); 
//         addressToPromotions[_owner].push(drawingIDs);
//         if (_mintsNFTs) {
//             receiptManager.setPromotionOwner(drawingIDs, _owner); 
//         }
//         drawingIDs+=1; 
//     }

//     function joinDrawing(uint256 drawingID, uint256 numOrders) public {
//         Drawing memory drawing = Drawings[drawingID];
//         uint256 numParticipants = promotionIDToReceiptIDs[drawingID].length;
//         console.log("1");
//         // Check if the promotion is expired or slots are full
//         if (numParticipants >= drawing.maxSlots ||  drawing.endTime < block.timestamp) {
//             revert Promotion_Expired();
//         } 
//         // Adjust order number if exceeding max slots
//         else if(numParticipants + numOrders > drawing.maxSlots) {
//             numOrders = drawing.maxSlots - numParticipants;
//         }
//         console.log("2");
//         // Calculate amounts
//         uint256 totalRebate = drawing.rebateAmount * numOrders;
//         uint256 totalSellerAmount = (drawing.price - drawing.rebateAmount) * numOrders;
//         uint256 commissionAmount = (totalSellerAmount) * commission / 10000;
//         uint256 totalAmount = totalRebate + totalSellerAmount;
//         console.log(totalRebate);
//         console.log(totalSellerAmount);
//         console.log(commissionAmount);
//         console.log(totalAmount);
//         console.log("9");
//         // Transfer funds
//         IERC20(drawing.erc20Token).transferFrom(msg.sender, address(this), totalAmount);
//         console.log("3a");
//         IERC20(drawing.erc20Token).transfer(promotionsManager.getReceiverAddress(drawing.owner, drawing.erc20Token), totalSellerAmount - commissionAmount);
//         console.log("4");
//         // Update balances
//         earnedCommissions[drawing.erc20Token] += commissionAmount;

//         // Mint NFT receipts and log details
//         uint256 initialReceiptID;
//         if (drawing.mintsNFTs) {
//             initialReceiptID = receiptManager.mintReceipts(
//                 msg.sender,
//                 drawingID,
//                 numParticipants + 1,
//                 numOrders
//             );
//         } else {
//             initialReceiptID = receiptManager.incrementReceiptIDs(numOrders);
//         }
//         console.log("5");

//         for (uint256 i = 0; i < numOrders; ++i) {
//             DrawingReceipt storage drawingReceipt = DrawingReceipts[initialReceiptID + i];
//             drawingReceipt.drawingID = drawingID; 

//             // Directly push to storage array
//             promotionIDToReceiptIDs[drawingID].push(initialReceiptID + i);

//             // Handle unminted receipt ownership
//             if (!drawing.mintsNFTs) {
//                 unmintedReceiptsToOwners[initialReceiptID + i] = msg.sender;
//             }
//         }
//         console.log("6");

//         // Update the number of participants
//         emit DrawingReceiptsMinted(msg.sender, drawingID, numParticipants +1, initialReceiptID, numOrders);
//         console.log("7");
//     }

//     function drawingEligibility(uint256 drawingID, uint256 cohort) public view returns (bool) {
//         Drawing storage drawing = Drawings[drawingID];
//         if(promotionIDToReceiptIDs[drawingID].length < drawing.cohortSize*(1+cohort) || raffleInitiatedBool[drawingID][cohort] == true || promotionIDToReceiptIDs[drawingID].length == 0) {
//             console.log(drawingID, cohort);
//             console.log("Ineligible");
//             return false; 
//         }
//         else {
//             console.log(drawingID, cohort);
//             console.log("eligible");
//             return true;
//         } 
//     } 

//     function initiateDrawings(uint64[] calldata arrayOfDrawingIDs, uint16[] calldata arrayOfcohorts) public {
//         // Check array lengths match
//         require(arrayOfDrawingIDs.length == arrayOfcohorts.length, "Array length mismatch");
//         require(arrayOfDrawingIDs.length <= 5, "Exceed length");
//         require(arrayOfDrawingIDs.length > 0, "Zero length");

//         // Pre-check eligibility for all entries
//         for (uint256 i = 0; i < arrayOfDrawingIDs.length; i++) {
//             require(drawingEligibility(arrayOfDrawingIDs[i], arrayOfcohorts[i]), "Ineligible entry");
//         }

//         // Process each drawingID and cohort
//         for (uint256 i = 0; i < arrayOfDrawingIDs.length; i++) {
//             raffleInitiatedBool[arrayOfDrawingIDs[i]][arrayOfcohorts[i]] = true;
//         }

//         // Convert length to uint32 for VRF call
//         uint32 numWords = uint32(arrayOfDrawingIDs.length);

//         // Request randomness
//         uint256 requestId = i_vrfCoordinator.requestRandomWords(
//             i_gasLane,
//             i_subscriptionId,
//             REQUEST_CONFIRMATIONS,
//             i_callbackGasLimit,
//             numWords // Number of random words to request (adjust if needed)
//         );

//         // Create storage reference to the context
//         VRFRequestContext storage context = vrfRequestIDtoContext[requestId];

//         // Manually copy arrays from calldata to storage
//         context.drawingIDArray = arrayOfDrawingIDs; // This copies elements
//         context.cohorts = arrayOfcohorts; // This copies elements
        

//         //emit event
//         emit RafflesInitiated(arrayOfDrawingIDs, requestId, msg.sender, arrayOfcohorts);
//     }

//     function fulfillRandomWords(
//         uint256 requestId, 
//         uint256[] memory randomWords
//     ) internal override {
//         VRFRequestContext storage context = vrfRequestIDtoContext[requestId];
//         console.log("fulfilling");
//         // Ensure we have enough random words
//         require(
//             randomWords.length == context.drawingIDArray.length, 
//             "Random words length mismatch"
//         );
//         console.log(context.drawingIDArray.length); 
        
//         // Process each drawing/cohort combination
//         for (uint i = 0; i < context.drawingIDArray.length; i++) {
//             uint256 drawingID = context.drawingIDArray[i];
//             uint256 cohort = context.cohorts[i];
//             uint256 randomWord = randomWords[i];
//             console.log("a");
            
//             uint256 cohortSize = Drawings[drawingID].cohortSize;
            
//             // Calculate winner position
//             uint256 winnerIndex = (cohort * cohortSize) + (randomWord % cohortSize);
//             uint256 winningReceiptID = promotionIDToReceiptIDs[drawingID][winnerIndex];
//             uint256 winningAmount = Drawings[drawingID].rebateAmount * cohortSize;
            
            
//             // Update receipt
//             DrawingReceipt storage drawingReceipt = DrawingReceipts[winningReceiptID];
//             drawingReceipt.redeemableAmount = winningAmount;
//             console.log(winningReceiptID);
//             console.log(winningAmount);
//             console.log(drawingReceipt.redeemableAmount);
            
//             // Emit event for this winner
//             emit RaffleWinner(
//                 drawingID,
//                 cohort,
//                 winningReceiptID,
//                 winnerIndex + 1,
//                 winningAmount,
//                 randomWord
//             );
//         }
//         console.log("b");
        
//         // Optional: Clean up storage to save gas
//         delete vrfRequestIDtoContext[requestId];
//     }


//     function redeemDrawingReceipts(uint256[] calldata receiptIDs) external {
//         uint256 redeemableAmount; 
//         address erc20Token = Drawings[DrawingReceipts[receiptIDs[0]].drawingID].erc20Token; //erc20 address of the first token
//         for(uint256 i =0; i < receiptIDs.length; i++) {
//             DrawingReceipt memory drawingReceipt = DrawingReceipts[receiptIDs[i]];
//             Drawing storage drawing = Drawings[drawingReceipt.drawingID];
//             require(erc20Token == drawing.erc20Token, "Invalid"); 
//             if(drawing.mintsNFTs) {
//                 require((receiptManager.ownerOf(receiptIDs[i]) == msg.sender), "Not owned");
//             }
//             else {
//                 require((unmintedReceiptsToOwners[receiptIDs[i]] == msg.sender), "Not owned");
//             }            
//             if(drawingReceipt.redeemableAmount >0) {
//                 redeemableAmount += drawingReceipt.redeemableAmount;
//                 DrawingReceipts[receiptIDs[i]].redeemableAmount = 0; 
//                 emit DrawingReceiptRedeemed(receiptIDs[i], drawingReceipt.drawingID, drawingReceipt.redeemableAmount); 
//             }
//         }
//         if(redeemableAmount !=0) {
//             IERC20(erc20Token).transfer(
//                 msg.sender,
//                 redeemableAmount
//             );
//         }
//     }


//     function cancelDrawing(uint256 drawingID) external {
//         Drawing storage drawing = Drawings[drawingID];
//         if (!promotionsManager.isApprovedOperator(msg.sender, drawing.owner)) {
//             revert NotApproved(); 
//         }
//         uint256 numParticipants = promotionIDToReceiptIDs[drawingID].length; 
//         if (drawing.endTime > block.timestamp && numParticipants < drawing.maxSlots) {
//             uint256 numBuyersToCompensate = numParticipants % drawing.cohortSize;
//             // Ensure we are compensating the last `numBuyersToCompensate` participants
//             uint256 startIndex = numParticipants - numBuyersToCompensate; // Start index for the last `numBuyersToCompensate`
//             uint256 endIndex = numParticipants - 1; // End index for the last participant

//             // Create a new array to hold the slice
//             uint256[] memory receiptsToCompensate = new uint256[](numBuyersToCompensate);

//             // Copy the elements from the original array to the new array
//             for (uint256 i = startIndex; i <= endIndex; i++) {
//                 receiptsToCompensate[i - startIndex] = promotionIDToReceiptIDs[drawingID][i];
//             }

//             // Pass the array to the rebate function
//             rebateDrawingReceipts(receiptsToCompensate, drawing.rebateAmount);
//             emit DrawingCancelled(drawingID, numBuyersToCompensate);
//             drawing.maxSlots = uint16(numParticipants); 
//             drawing.returnedCustody = true; 
//         }
//     }

//     function rebateDrawingReceipts(
//         uint256[] memory tokenIds,
//         uint256 rebateAmount
//     ) internal {
//         for (uint256 i = 0; i < tokenIds.length; i++) {
//             DrawingReceipt storage drawingReceipt = DrawingReceipts[
//                 tokenIds[i]
//             ];
//             drawingReceipt.redeemableAmount = rebateAmount;
//         }
//     }

//     function retrieveExcessDrawingCustody(uint256 drawingID) public {
//         Drawing memory drawing = Drawings[drawingID];
//         if (!promotionsManager.isApprovedOperator(msg.sender, drawing.owner)) {
//             revert NotApproved(); 
//         }
//         uint256 numParticipants = promotionIDToReceiptIDs[drawingID].length;
//         // Check if the custody has already been returned
//         require(block.timestamp > drawing.endTime || drawing.maxSlots == numParticipants, "Ineligible");
//         require(!drawing.returnedCustody, "Already Returned");

//         // Calculate excess custody based on remaining participants in last cohort
//         uint256 excessCustody = (numParticipants % drawing.cohortSize) * drawing.rebateAmount;

//         // Pay the contract  owner the remaining amount 
//         IERC20(drawing.erc20Token).transfer(contractOwner, excessCustody); 
        
//         // Update storage values
//         Drawing storage drawingStorage = Drawings[drawingID];
//         drawingStorage.returnedCustody = true;

//         //Emit the event
//         emit DrawingCustodyRedeemed(drawingID, excessCustody); 
//     }


//     function setPromotionURI(uint256 promotionID, string calldata newURIRoot) external override {
//         Drawing storage drawing =Drawings[promotionID]; 
//         if (!promotionsManager.isApprovedOperator(msg.sender, drawing.owner)) {
//             revert NotApproved(); 
//         }
//         if (!drawing.mintsNFTs) {
//             revert NotCustomURI(); 
//         }
//         if(bytes(receiptManager.customURIRoot(promotionID)).length != 0) {
//             revert URIAlreadSet();
//         }
//         receiptManager.modifyPromotionURI(promotionID, newURIRoot);
//     }

//     function setRoyalty(uint256 promotionID, uint256 basisPoints) external override {
//         Drawing storage drawing = Drawings[promotionID]; 
//         if (!promotionsManager.isApprovedOperator(msg.sender, drawing.owner)) {
//             revert NotApproved(); 
//         }
//         receiptManager.setRoyalty(promotionID, basisPoints);
//     }

// }