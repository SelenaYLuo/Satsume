// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error Promotion_Expired();
// error InvalidConfig(); 
// error NotApproved();
// error DoesNotExist();

// event DrawingCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 maxSlots, uint256 endTime, uint256 price, uint256 cohortSize, uint256 rebateAmount);
// event DrawingCustodyRedeemed(uint256 indexed promotionID, uint256 redeemedAmount); 
// event DrawingCancelled(uint256 indexed promotionID, uint256 numberOfParticipants);
// event SnowballCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 maxSlots, uint256 endTime, uint256[] thresholds, uint256[] cohortPrices);
// event SnowballCustodyRedeemed(uint256 indexed promotionID, uint256 redeemedAmount); 
// event SnowballCancelled(uint256 indexed promotionID, uint256 numberOfParticipants);
// event SeedCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 seeds, uint256 maxSlots, uint256 sharedAmount, uint256 endTime );
// event SeedCancelled(uint256 indexed promotionID, uint256 numberOfParticipants); 
// event OperatorApproved(address indexed owner, address indexed approvedOperator);
// event OperatorRemoved(address indexed owner, address indexed removedOperator);

// import "hardhat/console.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../interfaces/IReceiptManager.sol";
// import "../interfaces/IReceiptLogger.sol";




// contract PromotionManager { //} is VRFConsumerBaseV2  {
//     // Type Declarations
//     struct Snowball {
//         uint256 maxSlots; 
//         uint256 endTime;
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
//         uint256 endTime;
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
//         uint256 endTime; 
//         uint256 numParticipants;
//         uint256 sharedAmount;
//         address owner;
//         uint256 earnedAmount;
//         address erc20Token;
//         uint256 custodyBalance;
//     }

//     enum PromotionType { Snowball, Drawing, Seed }

    
    

//     /* State Variables */
//     uint256 public promotionIDs = 1; 
//     uint256 public constant MINIMUM_DURATION = 900; 
//     uint256 public commission = 200; // basis points (divided by 10,000)
//     address payable public bank;
//     address public owner; 
//     address public receiptManagerAddress; 
//     address public receiptLoggerAddress; 

//     mapping(uint256 => PromotionType) public promotionTypes;
//     mapping(uint256 => Snowball) public Snowballs;
//     mapping(uint256 => Drawing) public Drawings;
//     mapping(uint256 => Seed) public Seeds;
//     mapping(address => mapping(address => bool)) approvedOperators;
//     mapping(address => uint256) earnedCommissions;
//     mapping(address => uint256) withdrawnCommissions; 

//     IReceiptManager public receiptManager; 
//     IReceiptLogger public receiptLogger; 
    
//     constructor() { 
//         owner = msg.sender; // Set the owner to the contract deployer
//         bank = payable(owner);

//     }

//     modifier onlyOwner() {
//         require(msg.sender == owner, "NotOwner");
//         _;
//     }

//     modifier onlyReceiptManager() {
//         require(msg.sender == receiptManagerAddress, "NotOwner");
//         _;
//     }

//     modifier onlyReceiptLogger() {
//         require(msg.sender == receiptLoggerAddress, "NotOwner");
//         _;
//     }

//     function setBank(address payable newBank) external onlyOwner {
//         bank = payable(newBank);
//     }

//     function setOwner(address payable newOwner) external onlyOwner {
//         owner = payable(newOwner);
//     }

//     function setReceiptManager(address _receiptManagerAddress) external onlyOwner {
//         receiptManagerAddress = _receiptManagerAddress; 
//         receiptManager = IReceiptManager(_receiptManagerAddress); 
//     }

//     function setReceiptLogger(address _receiptLoggerAddress) external onlyOwner {
//         receiptLoggerAddress = _receiptLoggerAddress; 
//         receiptLogger = IReceiptLogger(_receiptLoggerAddress); 
//     }

//     //Approve main ERC20 stablecoins. Can later approve new coins. 
//     function approveERC20Token(address _erc20TokenAddress) external {
//         IERC20(_erc20TokenAddress).approve(receiptManagerAddress, type(uint256).max);
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
//     function createDrawing(
//         uint256 _maxSlots,
//         uint256 _duration,
//         uint256 _price,
//         uint256 _cohortSize,
//         uint256 _rebateAmount,
//         address _owner,
//         address _erc20Token
//     ) public {
//         if (_cohortSize<=1 || _maxSlots % _cohortSize != 0  || _duration < MINIMUM_DURATION || _maxSlots <= 1 || _rebateAmount >= _price) {
//             revert InvalidConfig();
//         }
//         if (msg.sender != _owner && !approvedOperators[_owner][msg.sender]) {
//             revert NotApproved(); 
//         }

//         // Initialize a new drawing contract and store it in storage
//         Drawing storage drawing = Drawings[promotionIDs];
//         drawing.maxSlots = _maxSlots;
//         drawing.owner = payable(_owner);
//         drawing.endTime = block.timestamp + _duration;
//         drawing.price = _price;
//         drawing.cohortSize = _cohortSize;
//         drawing.rebateAmount = _rebateAmount;
//         drawing.erc20Token = _erc20Token; 

        
//         emit DrawingCreated(_owner, promotionIDs, _erc20Token, _maxSlots, _duration + block.timestamp, _price, _cohortSize, _rebateAmount); 
//         promotionTypes[promotionIDs] = PromotionType.Drawing;
//         promotionIDs+=1; 
//     }

//     function joinDrawing(uint256 drawingID, uint256 numOrders) public {
//         Drawing memory drawing = Drawings[drawingID];

//         // Check if the promotion is expired or slots are full
//         if (drawing.numParticipants > drawing.maxSlots || 
//             drawing.endTime < block.timestamp) {
//             revert Promotion_Expired();
//         }
//         // Adjust order number if exceeding max slots
//         else if(drawing.numParticipants + numOrders > drawing.maxSlots) {
//             numOrders = drawing.maxSlots - drawing.numParticipants;
//         }

//         // Calculate amounts
//         uint256 totalRebate = drawing.rebateAmount * numOrders;
//         uint256 totalSellerAmount = (drawing.price - drawing.rebateAmount) * numOrders;
//         uint256 commissionAmount = calculateCommission(totalSellerAmount);
//         uint256 totalAmount = totalRebate + totalSellerAmount;

//         // Transfer funds
//         IERC20(drawing.erc20Token).transferFrom(msg.sender, address(this), totalAmount);
//         IERC20(drawing.erc20Token).transfer(drawing.owner, totalSellerAmount - commissionAmount);

//         // Update balances
//         Drawings[drawingID].custodyBalance += totalRebate;
//         earnedCommissions[drawing.erc20Token] += commissionAmount;

//         //Get total supply of receiptIDs
//         uint256 totalSupply = receiptManager.totalSupply();

//         //Log receipt details  
//         receiptLogger.createDrawingReceipts(
//             msg.sender,
//             drawingID, 
//             drawing.numParticipants + 1,
//             drawing.erc20Token, 
//             numOrders,
//             totalSupply
//         );

//         //Mint NFT-Receipts
//         receiptManager.mintReceipts(msg.sender, numOrders, drawingID, drawing.numParticipants + 1);

//         // Update the number of participants
//         Drawings[drawingID].numParticipants += numOrders;
//     }

//     function retrieveExcessDrawingCustody(uint256 drawingID) public {
//         Drawing memory drawing = Drawings[drawingID];

//         // Check if the custody has already been returned
//         require(block.timestamp > drawing.endTime || drawing.maxSlots == drawing.numParticipants, "Ineligible");
//         require(!drawing.returnedCustody, "Already Returned");

//         // Calculate excess custody based on remaining participants after filling cohorts
//         uint256 excessCustody = (drawing.numParticipants % drawing.cohortSize) * drawing.rebateAmount;
        
//         // Calculate and deduct commission
//         uint256 commissionAmount = calculateCommission(excessCustody);
//         earnedCommissions[drawing.erc20Token] += commissionAmount;

//         // Pay the owner the remaining amount after deducting the commission
//         IERC20(drawing.erc20Token).transfer(drawing.owner, excessCustody - commissionAmount); 
        
//         // Update storage values
//         Drawing storage drawingStorage = Drawings[drawingID];
//         drawingStorage.custodyBalance -= excessCustody;
//         drawingStorage.returnedCustody = true;

//         //Emit the event
//         emit DrawingCustodyRedeemed(drawingID, excessCustody); 
//     }


//     function reduceCustodyBalance(uint256 promotionID, uint256 reductionAmount) onlyReceiptLogger external {
//         PromotionType promoType = promotionTypes[promotionID];
//         if(promoType == PromotionType.Snowball) {
//             Snowballs[promotionID].custodyBalance -= reductionAmount;
//         }
//         else if (promoType == PromotionType.Drawing) {
//             Drawings[promotionID].custodyBalance -= reductionAmount;
//         }
//         else {
//             Seeds[promotionID].custodyBalance -= reductionAmount;
//         }
//     }

//     function getDrawingCohortSizeAndRebate(uint256 drawingID) public view returns(uint256, uint256) {
//         Drawing storage drawing = Drawings[drawingID];
//         return (drawing.cohortSize, drawing.rebateAmount); 
//     }

//     function drawingEligibility(uint256 drawingID, uint256 cohort) public view returns (bool) {
//         bool eligibility = true; 
//         if( Drawings[drawingID].numParticipants < Drawings[drawingID].cohortSize*(1+cohort)) {
//             eligibility=false; 
//         }
//         return eligibility; 
//     } 

//     function cancelPromotion(uint256 promotionID) public {
//         PromotionType promoType = promotionTypes[promotionID];
//         if (promoType == PromotionType.Snowball) {
//             Snowball storage snowball =Snowballs[promotionID]; 
//             if (msg.sender != snowball.owner && !approvedOperators[snowball.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//             if(snowball.endTime > block.timestamp && snowball.numParticipants < snowball.maxSlots) {
//                 snowball.maxSlots = snowball.numParticipants;
//                 emit SnowballCancelled(promotionID, snowball.numParticipants);
//             }
//         }
//         else if (promoType == PromotionType.Drawing) {
//             Drawing storage drawing = Drawings[promotionID];
//             if (msg.sender != drawing.owner && !approvedOperators[drawing.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//             if (drawing.endTime > block.timestamp && drawing.numParticipants < drawing.maxSlots) {
//                 uint256 numBuyersToCompensate = drawing.numParticipants % drawing.cohortSize;
//                 // Ensure we are compensating the last `numBuyersToCompensate` participants
//                 uint256 totalParticipants = drawing.numParticipants;
//                 uint256 startIndex = totalParticipants - numBuyersToCompensate; // Start index for the last `numBuyersToCompensate`
//                 uint256 endIndex = totalParticipants - 1; // End index for the last participant

//                 // Get the last `numBuyersToCompensate` token IDs using the range
//                 uint256[] memory receiptsToCompensate = receiptLogger.getTokenIDsInRange(promotionID, startIndex, endIndex);
//                 // // Declare an array to hold IDs of receipts to compensate
//                 // uint256[] memory receiptsToCompensate = new uint256[](numBuyersToCompensate);

//                 // for (uint256 i = 0; i < numBuyersToCompensate; i++) {
//                 //     receiptsToCompensate[i] = receiptManager.promotionToTokenIDs(promotionID, drawing.numParticipants-1-i);
//                 // }

//                 // Pass the array to the rebate function
//                 receiptLogger.rebateDrawingReceipts(receiptsToCompensate, drawing.rebateAmount);
//                 emit DrawingCancelled(promotionID, numBuyersToCompensate);
//             }
//         }
//         else if(promoType == PromotionType.Seed) {
//             Seed storage seed = Seeds[promotionID];
//             if (msg.sender != seed.owner && !approvedOperators[seed.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//             if (seed.endTime > block.timestamp && seed.numParticipants < seed.maxSlots) {
//                 seed.maxSlots = seed.numParticipants;
//                 emit SeedCancelled(promotionID, seed.numParticipants);
//             }
//         }
//     }

    
//     function createSnowball(
//         uint256 _maxSlots,
//         uint256 _duration,
//         uint256[] calldata _cohortPrices,
//         uint256[] calldata _thresholds,
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
//             if (i != 0) {
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
//         snowball.thresholds = _thresholds;
//         snowball.owner = payable(_owner);
//         snowball.endTime = block.timestamp +_duration;
//         snowball.cohortPrices = _cohortPrices;
//         snowball.erc20Token = _erc20Token;
//         IERC20(_erc20Token).approve(receiptManagerAddress, type(uint256).max);


//         emit SnowballCreated(_owner, promotionIDs, _erc20Token, _maxSlots, _duration + block.timestamp, _thresholds, _cohortPrices);
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

//     function joinSnowball(uint256 snowballID, uint256 numOrders) public {
//         Snowball storage snowball = Snowballs[snowballID]; // Use storage reference to minimize repeated storage reads
//         uint256 numParticipants = snowball.numParticipants; 
//         address erc20Token = snowball.erc20Token; 

//         // Check for expiration or slot limits
//         require(block.timestamp < snowball.endTime, "Expired");
//         require(numParticipants + numOrders <= snowball.maxSlots, "Full");

//         uint256 newPrice = snowball.cohortPrices[0]; //Set to price of first cohort
//         for(uint256 i =0; i < snowball.thresholds.length; i++) {
//             if(numParticipants + numOrders >= snowball.thresholds[i]) {
//                 newPrice = snowball.cohortPrices[i+1];
//             }
//             else {
//                 break;
//             }
//         }

//         uint256 minPrice = snowball.cohortPrices[snowball.cohortPrices.length - 1];
//         uint256 totalCustodyAmount = (newPrice - minPrice) * numOrders;

//         // Update custody balance if needed
//         if (totalCustodyAmount != 0) {
//             snowball.custodyBalance += totalCustodyAmount;
//         }

//         // Calculate commission
//         uint256 commissionAmount = calculateCommission(numOrders * minPrice);

//         // Perform a single transfer for efficiency
//         IERC20(erc20Token).transferFrom(msg.sender, address(this), newPrice*numOrders);

//         // Update commissions and pay the owner
//         earnedCommissions[erc20Token] += commissionAmount;
//         uint256 ownerPayment = numOrders * minPrice - commissionAmount;
//         IERC20(erc20Token).transfer(snowball.owner, ownerPayment);

//          //Get total supply of receiptIDs
//         uint256 totalSupply = receiptManager.totalSupply();

//         //Log receipt details  
//         receiptLogger.createSnowballReceipts(
//             msg.sender,
//             snowballID, 
//             numParticipants + 1,
//             newPrice,
//             erc20Token, 
//             numOrders,
//             totalSupply
//         );

//         //Mint NFT-Receipts
//         receiptManager.mintReceipts(msg.sender, numOrders, snowballID, numParticipants + 1);

//         // Update participants count
//         snowball.numParticipants += numOrders;
//     }

//     function retrieveExcessSnowballCustody(uint256 snowballID) public {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         //Check that the snowball has ended
//         require((block.timestamp > snowball.endTime || snowball.maxSlots == snowball.numParticipants) && !snowball.returnedCustody, "Ineligible");
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
//         seed.endTime = block.timestamp + _duration;
//         seed.sharedAmount = _sharedAmount;
//         seed.erc20Token = _erc20Token; 
//         seed.owner = _owner; 
//         IERC20(_erc20Token).approve(receiptManagerAddress, type(uint256).max);

//         emit SeedCreated(_owner, promotionIDs, _erc20Token, _seeds, _maxSlots, _sharedAmount, _duration + block.timestamp);
//         promotionIDs += 1; 
//     }

//     function joinSeed(uint256 seedID, uint256 numOrders) public {
//         Seed memory seed = Seeds[seedID];

//         require(
//             seed.endTime > block.timestamp &&
//             seed.numParticipants + numOrders <= seed.maxSlots,
//             "Full"
//         );

//         uint256 availableSeededSlots = seed.seeds > seed.numParticipants ? seed.seeds - seed.numParticipants : 0;
//         uint256 seededParticipants = numOrders > availableSeededSlots ? availableSeededSlots : numOrders;
//         uint256 unseededParticipants = numOrders - seededParticipants;

//         // Get total supply of receiptIDs
//         uint256 totalSupply = receiptManager.totalSupply();

//         receiptLogger.createSeedReceipts(
//                 msg.sender,
//                 seedID,
//                 seed.numParticipants + 1,
//                 seed.erc20Token,
//                 seededParticipants,
//                 unseededParticipants,
//                 totalSupply
//             );

//         // Mint NFT-Receipts for all receipts
//         receiptManager.mintReceipts(msg.sender, numOrders, seedID, seed.numParticipants + 1);

//         // Update participant count in storage
//         seed.numParticipants += numOrders;

//         // Commission and transfer calculations
//         uint256 sharedAmount = seed.sharedAmount * unseededParticipants;
//         uint256 amountToSeller =
//             (seededParticipants * seed.price) +
//             (unseededParticipants * (seed.price - seed.sharedAmount));

//         uint256 totalCommission = calculateCommission(seed.price*numOrders);
//         uint256 commissionOnSeller = totalCommission * amountToSeller / (sharedAmount+amountToSeller); 
//         uint256 commissionOnShared = totalCommission - commissionOnSeller; 

//         // Update balances in storage
//         seed.earnedAmount += sharedAmount - commissionOnShared;
//         seed.custodyBalance += sharedAmount - commissionOnShared;
//         earnedCommissions[seed.erc20Token] += totalCommission;

//         // Single transferFrom call for the total amount
//         IERC20(seed.erc20Token).transferFrom(
//             msg.sender,
//             address(this),
//             sharedAmount + amountToSeller
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

    

//     function getPromotionOwner(uint256 promotionID) external view returns (address) {
//         if(promotionTypes[promotionID] == PromotionType.Snowball) {
//             return Snowballs[promotionID].owner;
//         } 
//         else if(promotionTypes[promotionID] == PromotionType.Drawing) {
//             return Drawings[promotionID].owner;
//         } 
//         else if(promotionTypes[promotionID] == PromotionType.Seed) {
//             return Seeds[promotionID].owner;
//         } 
//         else {
//             revert DoesNotExist();
//         }

//     }

//     function getSnowball(uint256 snowballID)
//         public
//         view
//         returns (
//             uint256 maxSlots,
//             uint256 endTime,
//             uint256 numParticipants,
//             uint256 custodyBalance,
//             address snowballOwner,
//             bool returnedCustody,
//             address erc20Token,
//             uint256[] memory thresholds,
//             uint256[] memory cohortPrices
//         )
//     {
//         Snowball storage snowball = Snowballs[snowballID];
//         return (
//             snowball.maxSlots,
//             snowball.endTime,
//             snowball.numParticipants,
//             snowball.custodyBalance,
//             snowball.owner,
//             snowball.returnedCustody,
//             snowball.erc20Token,
//             snowball.thresholds,
//             snowball.cohortPrices
//         );
//     }

// }
