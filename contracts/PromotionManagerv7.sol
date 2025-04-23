// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error Promotion_Expired();
// error InvalidConfig(); 
// error NotApproved();
// error DoesNotExist();
// error WrongPromotionManager();

// event SnowballCreated(address indexed owner, uint256 indexed snowballID, address indexed erc20Token, uint256 maxSlots, uint256 endTime, uint256[] thresholds, uint256[] cohortPrices);
// event SnowballCustodyRedeemed(uint256 indexed snowballID, uint256 redeemedAmount); 
// event SnowballCancelled(uint256 indexed snowballID, uint256 numberOfParticipants);
// event SnowballReceiptRedeemed(uint256 indexed tokenID, uint256 indexed snowballID, uint256 redeemedAmount); 
// event SnowballReceiptsMinted(address indexed joiner, uint256 indexed snowballID, uint256 firstParticipantNumber, uint256 firstTokenID, uint256 pricePaid, uint256 numTickets);

// event SeedCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 seeds, uint256 maxSlots, uint256 sharedAmount, uint256 endTime );
// event SeedCancelled(uint256 indexed promotionID, uint256 numberOfParticipants); 
// event SeedReceiptsMinted(address indexed joiner, uint256 promotionID, uint256 firstParticipantNumber, uint256  firstTokenID, bool seeded, uint256 numTickets);
// event SeedReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 redeemedAmount); 

// event OperatorApproved(address indexed owner, address indexed approvedOperator);
// event OperatorRemoved(address indexed owner, address indexed removedOperator);


// import "hardhat/console.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../interfaces/IReceiptManager.sol";

// contract PromotionManager {
//     struct Snowball {
//         uint256 maxSlots; 
//         uint256 endTime;
//         uint256[] thresholds;
//         uint256[] cohortPrices; 
//         address owner; 
//         bool returnedCustody; 
//         address erc20Token; 
//     }

//     struct SnowballReceipt {
//         uint256 snowballID;
//         uint256 effectivePricePaid;
//         uint256 participantNumber;
//     }

//     struct Seed {
//         uint256 numSeeds;
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

//     struct SeedReceipt {
//         uint256 seedID;
//         uint256 redeemedAmount;
//         bool seeded;
//     }

//     uint256 public snowballIDs = 1;
//     uint256 public seedIDs = type(uint256).max / 10 + 1;
//     uint256 public constant MINIMUM_DURATION = 900; 
//     uint256 public commission = 200; // basis points (divided by 10,000)
//     address payable public bank;
//     address public owner; 
//     address public receiptManagerAddress; 

//     mapping(uint256 => SnowballReceipt) public SnowballReceipts;
//     mapping(uint256 => Snowball) public Snowballs;
//     mapping(uint256 => Seed) public Seeds;
//     mapping(uint256 => SeedReceipt) public SeedReceipts;
//     mapping(address => mapping(address => bool)) approvedOperators;
//     mapping(address => address[]) arrayOfApprovedOperators; 
//     mapping(address => uint256[]) addressToPromotions;
//     mapping(address => uint256) earnedCommissions;
//     mapping(address => uint256) withdrawnCommissions; 

//     IReceiptManager public receiptManager; 

//     constructor(address _receiptManagerAddress) { 
//         owner = msg.sender; // Set the owner to the contract deployer
//         bank = payable(owner);
//         receiptManager = IReceiptManager(_receiptManagerAddress); 
//         receiptManagerAddress = _receiptManagerAddress;
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

//     function setOwner(address payable newOwner) external onlyOwner {
//         owner = payable(newOwner);
//     }

//     function setReceiptManager(address _receiptManagerAddress) external onlyOwner {
//         receiptManagerAddress = _receiptManagerAddress; 
//         receiptManager = IReceiptManager(_receiptManagerAddress); 
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
//         require(!approvedOperators[msg.sender][approvedOperator], "Operator already approved.");

//         approvedOperators[msg.sender][approvedOperator] = true;
//         arrayOfApprovedOperators[msg.sender].push(approvedOperator);

//         emit OperatorApproved(msg.sender, approvedOperator);
//     }

//     function removeOperator(address toRemove) public {
//         require(approvedOperators[msg.sender][toRemove], "Operator not approved.");

//         approvedOperators[msg.sender][toRemove] = false;

//         // Remove the address from the array
//         address[] storage operators = arrayOfApprovedOperators[msg.sender];
//         for (uint256 i = 0; i < operators.length; i++) {
//             if (operators[i] == toRemove) {
//                 operators[i] = operators[operators.length - 1]; // Replace with the last element
//                 operators.pop(); // Remove the last element
//                 break;
//             }
//         }

//         emit OperatorRemoved(msg.sender, toRemove);
//     }

//     function getApprovedOperators(address masterAccount) external view returns (address[] memory) {
//         return arrayOfApprovedOperators[masterAccount];
//     }

//     function modifyPromotionURI(
//         uint256 promotionID, 
//         string calldata _modifiedNameRoot,
//         bool _modifiedNameAppendNumber,
//         bool _dynamicImageBool,
//         string calldata _modifiedImageRoot,
//         string calldata _dynamicImageType
//     ) external {
//         if (promotionID  < type(uint256).max / 10 + 1) {
//             Snowball storage snowball = Snowballs[promotionID]; 
//             if (msg.sender != snowball.owner && !approvedOperators[snowball.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//         }
//         else {
//             Seed storage seeds = Seeds[promotionID]; 
//             if (msg.sender != seeds.owner && !approvedOperators[seeds.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//         }
//         receiptManager.modifyPromotionURI(promotionID, _modifiedNameRoot, _modifiedNameAppendNumber, _dynamicImageBool, _modifiedImageRoot, _dynamicImageType);
//     }

//     function customizePromotionURI(uint256 promotionID, string calldata _customURIRoot) external {
//         if (promotionID  < type(uint256).max / 10 + 1) {
//             Snowball storage snowball = Snowballs[promotionID]; 
//             if (msg.sender != snowball.owner && !approvedOperators[snowball.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//         }
//         else {
//             Seed storage seeds = Seeds[promotionID]; 
//             if (msg.sender != seeds.owner && !approvedOperators[seeds.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//         }
//         receiptManager.customizePromotionURI(promotionID, _customURIRoot);
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
//         Snowball storage snowball = Snowballs[snowballIDs];
//         snowball.maxSlots = _maxSlots;
//         snowball.thresholds = _thresholds;
//         snowball.owner = payable(_owner);
//         snowball.endTime = block.timestamp +_duration;
//         snowball.cohortPrices = _cohortPrices;
//         snowball.erc20Token = _erc20Token;

//         emit SnowballCreated(_owner, snowballIDs, _erc20Token, _maxSlots, _duration + block.timestamp, _thresholds, _cohortPrices);
//         addressToPromotions[_owner].push(snowballIDs);
//         snowballIDs += 1; 
//     }

//     function joinSnowball(uint256 snowballID, uint256 numOrders) public {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         uint256 numParticipants = receiptManager.numTokensByPromotion(snowballID); 
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
//         // Calculate commission
//         uint256 commissionAmount = (numOrders * minPrice)*commission/10000;

//         // Perform a single transfer for efficiency
//         IERC20(erc20Token).transferFrom(msg.sender, address(this), newPrice*numOrders);

//         // Update commissions and pay the owner
//         earnedCommissions[erc20Token] += commissionAmount;
//         uint256 ownerPayment = numOrders * minPrice - commissionAmount;
//         IERC20(erc20Token).transfer(snowball.owner, ownerPayment);

//         //Mint NFT-Receipts
//         uint256 initialTokenID = receiptManager.mintReceipts(msg.sender, snowballID, numParticipants+1, numOrders); 

//         //Log the receipt details
//         for (uint256 i=0; i<numOrders; i++) {
//             SnowballReceipt storage snowballReceipt = SnowballReceipts[initialTokenID + i];
//             snowballReceipt.snowballID = snowballID;
//             snowballReceipt.effectivePricePaid = newPrice; 
//             snowballReceipt.participantNumber = numParticipants + 1 + i; 
//         }

//         emit SnowballReceiptsMinted(
//             msg.sender, 
//             snowballID, 
//             numParticipants+1, 
//             5,
//             newPrice, 
//             numOrders
//         );
//     }

//     function redeemSnowballReceipts(uint256[] calldata tokenIDs) external {
//         uint256 redeemableAmount; 
//         address erc20Token = Snowballs[SnowballReceipts[tokenIDs[0]].snowballID].erc20Token; //erc20 address of the first token
//         for(uint256 i =0; i < tokenIDs.length; i++) {
//             SnowballReceipt memory snowballReceipt = SnowballReceipts[tokenIDs[i]];
//             Snowball storage snowball = Snowballs[snowballReceipt.snowballID];
//             require(erc20Token == snowball.erc20Token, "Invalid"); 
//             require((receiptManager.ownerOf(tokenIDs[i]) == msg.sender), "Not owned");
//             uint256 snowballPrice = getSnowballPrice(snowballReceipt.snowballID);
//             if (snowballReceipt.effectivePricePaid > snowballPrice) {
//                 redeemableAmount += (snowballReceipt.effectivePricePaid - snowballPrice);
//                 SnowballReceipts[tokenIDs[i]].effectivePricePaid = snowballPrice;
//                 emit SnowballReceiptRedeemed(tokenIDs[i], snowballReceipt.snowballID, snowballReceipt.effectivePricePaid - snowballPrice);
//             }
//         }
//         if(redeemableAmount !=0) {
//             IERC20(erc20Token).transfer(
//                 msg.sender,
//                 redeemableAmount
//             );
//         }
//     }

//     function getSnowballPrice(uint256 snowballID) public view returns(uint256) {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         uint256 numParticipants = receiptManager.numTokensByPromotion(snowballID);
//         if(snowball.maxSlots == numParticipants) {
//             /*
//             In this case, the price must be that of the last cohort. This specific 
//             check method is needed as cancelling a Snowball early sets maxSlots to numParticipants, 
//             thus looping through thresholds will not produce the intended result of 
//             returning the lowest possible price. 
//             */
//             return snowball.cohortPrices[snowball.cohortPrices.length-1]; 
//         }
//         uint256 updatedPrice = snowball.cohortPrices[0]; //Set to price of first cohort
//         uint256 thresholdsLength = snowball.thresholds.length;
//         for (uint256 i = 0; i < thresholdsLength; i++) {
//             if(numParticipants >= snowball.thresholds[i]) {
//                 updatedPrice = snowball.cohortPrices[i+1];
//             }
//             else{
//                 break;
//             } 
//         }
//         return updatedPrice; 
//     }

//     function retrieveExcessSnowballCustody(uint256 snowballID) public {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         uint256 numParticipants = receiptManager.numTokensByPromotion(snowballID);
//         //Check that the snowball has ended
//         require((block.timestamp > snowball.endTime || snowball.maxSlots == numParticipants) && !snowball.returnedCustody, "Ineligible");
//         // Caculate excess custody
//         uint256 excessCustody = calculateExcessSnowballCustody(snowballID);        
//         //Return excess if the snowball has ended
//         uint256 commissionAmount = excessCustody*commission/10000; //Commission is on all proceeds to sellers. 
//         earnedCommissions[snowball.erc20Token] += commissionAmount;
//         IERC20(snowball.erc20Token).transfer(snowball.owner, excessCustody-commissionAmount); 
//         snowball.custodyBalance -=excessCustody; 
//         snowball.returnedCustody = true; 
//         emit SnowballCustodyRedeemed(snowballID, excessCustody);
//     }
    

//     function calculateExcessSnowballCustody(uint256 snowballID) public view returns(uint256) {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         uint256 numParticipants = receiptManager.numTokensByPromotion(snowballID);
//         if ((snowball.endTime > block.timestamp && snowball.maxSlots > numParticipants) || snowball.returnedCustody) {
//             return 0; 
//         }
//         uint256 currentPrice = getSnowballPrice(snowballID);
//         uint256 excessCustody = (currentPrice-snowball.cohortPrices[snowball.cohortPrices.length-1]) * numParticipants;
//         return  excessCustody;
//     }

//     function createSeed(uint256 _seeds, uint256 _maxSlots, uint256 _price, uint256 _duration, uint256 _sharedAmount, address _owner, address _erc20Token) public {
//         if (_seeds >= _maxSlots || _sharedAmount >= _price || _duration < MINIMUM_DURATION || _maxSlots <= 1) {
//             revert InvalidConfig();
//         }
//         if (msg.sender != _owner && !approvedOperators[_owner][msg.sender]) {
//             revert NotApproved(); 
//         }

//         // Initialize a new seed contract and store it in storage
//         Seed storage seed = Seeds[seedIDs];
//         seed.numSeeds = _seeds;
//         seed.maxSlots = _maxSlots;
//         seed.price = _price;
//         seed.endTime = block.timestamp + _duration;
//         seed.sharedAmount = _sharedAmount;
//         seed.erc20Token = _erc20Token; 
//         seed.owner = _owner; 

//         emit SeedCreated(_owner, seedIDs, _erc20Token, _seeds, _maxSlots, _sharedAmount, _duration + block.timestamp);
//         addressToPromotions[_owner].push(seedIDs);
//         seedIDs += 1; 
//     }

//     function setRoyalty(uint256 promotionID, uint256 basisPoints, address receiver) external {
//         if (promotionID  < type(uint256).max / 10 + 1) {
//             Snowball storage snowball = Snowballs[promotionID]; 
//             if (msg.sender != snowball.owner && !approvedOperators[snowball.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//         }
//         else {
//             Seed storage seeds = Seeds[promotionID]; 
//             if (msg.sender != seeds.owner && !approvedOperators[seeds.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//         }
//         receiptManager.setRoyalty(promotionID, basisPoints, receiver);
//     }

//      function joinSeed(uint256 seedID, uint256 numOrders) public {
//         // Load seed into memory for efficient access
//         Seed memory seed = Seeds[seedID];

//         // Validate input
//         require(
//             block.timestamp < seed.endTime &&
//             seed.numParticipants + numOrders <= seed.maxSlots,
//             "Full"
//         );

//         // Determine seeded and unseeded participants
//         uint256 availableSeededSlots = seed.numSeeds > seed.numParticipants
//             ? seed.numSeeds - seed.numParticipants
//             : 0;
//         uint256 seededParticipants = numOrders > availableSeededSlots
//             ? availableSeededSlots
//             : numOrders;
//         uint256 unseededParticipants = numOrders - seededParticipants;

//         // Mint NFT receipts and log details
//         uint256 initialTokenID = receiptManager.mintReceipts(
//             msg.sender,
//             seedID,
//             seed.numParticipants + 1,
//             numOrders
//         );
//         if(seededParticipants !=0) {
//             emit SeedReceiptsMinted(msg.sender, seedID, seed.numParticipants, initialTokenID, true, seededParticipants);
//         }
//         if(unseededParticipants !=0) {
//             emit SeedReceiptsMinted(msg.sender, seedID, seed.numParticipants + seededParticipants, initialTokenID + seededParticipants, false, unseededParticipants);
//         }
        

//         for (uint256 i = 0; i < numOrders; ++i) {
//             SeedReceipt storage seedReceipt = SeedReceipts[initialTokenID + i];
//             seedReceipt.seedID = seedID;
//             seedReceipt.seeded = (i < seededParticipants);
//         }

//         // Update participant count in storage
//         Seeds[seedID].numParticipants += numOrders;

//         // Calculate payment amounts
//         uint256 sharedAmount = seed.sharedAmount * unseededParticipants;
//         uint256 amountToSeller = (seededParticipants * seed.price) +
//             (unseededParticipants * (seed.price - seed.sharedAmount));

//         // Calculate total commission and breakdown
//         uint256 totalCommission = (seed.price * numOrders * commission) / 10000;
//         uint256 commissionOnSeller = (totalCommission * amountToSeller) /
//             (sharedAmount + amountToSeller);

//         if (sharedAmount > 0) {
//             uint256 commissionOnShared = totalCommission - commissionOnSeller;

//             // Update balances for shared participants
//             seed.earnedAmount += sharedAmount - commissionOnShared;
//             seed.custodyBalance += sharedAmount - commissionOnShared;
//         }

//         // Update earned commissions
//         earnedCommissions[seed.erc20Token] += totalCommission;

//         // Perform ERC20 transfers (unchanged)
//         IERC20(seed.erc20Token).transferFrom(
//             msg.sender,
//             address(this),
//             sharedAmount + amountToSeller
//         );

//         IERC20(seed.erc20Token).transfer(
//             seed.owner,
//             amountToSeller - commissionOnSeller
//         );
//     }

//     function seedRedeemableAmount(uint256 seedID) public view returns (uint256) {
//         Seed storage seed = Seeds[seedID];
//         return seed.earnedAmount/seed.numSeeds; 
//     }

//     function redeemSeedReceipts(uint256[] calldata tokenIDs) external {
//         uint256 redeemableAmount; 
//         address erc20Token = Seeds[SeedReceipts[tokenIDs[0]].seedID].erc20Token; //erc20 address of the first token
//         for(uint256 i =0; i < tokenIDs.length; i++) {
//             SeedReceipt memory seedReceipt = SeedReceipts[tokenIDs[i]];
//             Seed storage seed = Seeds[seedReceipt.seedID];
//             require(erc20Token == seed.erc20Token, "Invalid"); 
//             require((receiptManager.ownerOf(tokenIDs[i]) == msg.sender), "Not owned");
//             if(seedReceipt.seeded == true) {
//                 uint256 seedRedeemable = seed.earnedAmount/seed.numSeeds;
//                 if(seedReceipt.redeemedAmount < seedRedeemable) {
//                     SeedReceipts[tokenIDs[i]].redeemedAmount = seedRedeemable;
//                     redeemableAmount += seedRedeemable; 
//                     reduceSeedCustody(seedReceipt.seedID, seedRedeemable -seedReceipt.redeemedAmount);
//                     emit SeedReceiptRedeemed(tokenIDs[i], seedReceipt.seedID, seedRedeemable -seedReceipt.redeemedAmount);
//                 }
//             }
//         }
//         if(redeemableAmount !=0) {
//             IERC20(erc20Token).transfer(
//                 msg.sender,
//                 redeemableAmount
//             );
//         }
//     }

//     function reduceSeedCustody(uint256 seedID, uint256 reductionAmount) internal {
//         Seed storage seed = Seeds[seedID];
//         seed.custodyBalance -= reductionAmount; 
//     }

//     function getPromotionOwner(uint256 promotionID) external view returns(address) {
//         if(promotionID >= type(uint256).max / 10 + 1) {
//             return Seeds[promotionID].owner;
//         }
//         else {
//             return Snowballs[promotionID].owner;
//         }
//     }
    
//     // Function to get all properties of a Snowball struct, including arrays
//     function getSnowball(uint256 snowballId) 
//         public 
//         view 
//         returns (
//             uint256 maxSlots,
//             uint256 endTime,
//             uint256 numParticipants,
//             uint256[] memory thresholds,
//             uint256[] memory cohortPrices,
//             uint256 custodyBalance,
//             address owner,
//             bool returnedCustody,
//             address erc20Token
//         ) 
//     {
//         Snowball storage snowball = Snowballs[snowballId];
//         return (
//             snowball.maxSlots,
//             snowball.endTime,
//             snowball.numParticipants,
//             snowball.thresholds,
//             snowball.cohortPrices,
//             snowball.custodyBalance,
//             snowball.owner,
//             snowball.returnedCustody,
//             snowball.erc20Token
//         );
//     }

//     function getPromotionsByOwner(address promotionOwner) public view returns (uint256[] memory) {
//         return addressToPromotions[promotionOwner];
//     }

//     function cancelPromotion(uint256 promotionID) public {
//         if (promotionID <= type(uint256).max / 10) {
//             Snowball storage snowball =Snowballs[promotionID]; 
//             if (msg.sender != snowball.owner && !approvedOperators[snowball.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//             if(snowball.endTime > block.timestamp && snowball.numParticipants < snowball.maxSlots) {
//                 snowball.maxSlots = snowball.numParticipants;
//                 emit SnowballCancelled(promotionID, snowball.numParticipants);
//             }
//         }
//         else if(promotionID <= type(uint256).max / 10 * 2) {
//             Seed storage seed = Seeds[promotionID];
//             if (msg.sender != seed.owner && !approvedOperators[seed.owner][msg.sender]) {
//                 revert NotApproved(); 
//             }
//             if (seed.endTime > block.timestamp && seed.numParticipants < seed.maxSlots) {
//                 seed.maxSlots = seed.numParticipants;
//                 emit SeedCancelled(promotionID, seed.numParticipants);
//             }
//         }
//         else {
//             revert WrongPromotionManager(); 
//         }
//     }
// }