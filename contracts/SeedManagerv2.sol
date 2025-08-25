// pragma solidity ^0.8.24;

// error Promotion_Expired();
// error InvalidConfig(); 
// error NotApproved();
// event SeedCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 seeds, uint256 maxSlots, uint256 sharedAmount, uint256 endTime, bool mintsNFTs);
// event SeedCancelled(uint256 indexed promotionID, uint256 numberOfParticipants); 
// event SeedReceiptsMinted(address indexed joiner, uint256 promotionID, uint256 firstParticipantNumber, uint256  firstTokenID, bool seeded, uint256 numTickets);
// event SeedReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 redeemedAmount); 

// import "hardhat/console.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./PromotionManagerv9.sol";

// contract SeedManager is PromotionManager {
//     struct Seed {
//         uint256 numSeeds;
//         uint256 maxSlots;
//         uint256 price;
//         uint256 endTime; 
//         uint256 sharedAmount;
//         address owner;
//         uint256 earnedAmount;
//         address erc20Token;
//         bool mintsNFTs; 
//     }

//     struct SeedReceipt {
//         uint256 seedID;
//         uint256 redeemedAmount;
//         bool seeded;
//     }


//     uint256 public seedIDs = 100; //type(uint256).max / 10 + 1;
//     uint256 public constant MINIMUM_DURATION = 900; 
//     mapping(uint256 => Seed) public Seeds;
//     mapping(uint256 => SeedReceipt) public SeedReceipts;

//     constructor(address _receiptManagerAddress, address _promotionsManagerAddress) { 
//         contractOwner = msg.sender; // Set the owner to the contract deployer
//         receiptManager = IReceiptManager(_receiptManagerAddress); 
//         receiptManagerAddress = _receiptManagerAddress;
//         promotionsManagerAddress = _promotionsManagerAddress;  
//         promotionsManager = IPromotionsManager(_promotionsManagerAddress);
//     }

//     function createSeed(uint256 _seeds, uint256 _maxSlots, uint256 _price, uint256 _duration, uint256 _sharedAmount, address _owner, address _erc20Token, bool _mintsNFTs) public onlyApprovedOperators(_owner)  {
//         if (_seeds >= _maxSlots || _sharedAmount >= _price || _duration < MINIMUM_DURATION || _maxSlots <= 1 || _seeds ==0 || _maxSlots <=1)  {
//             revert InvalidConfig();
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
//         seed.mintsNFTs = _mintsNFTs; 

//         emit SeedCreated(_owner, seedIDs, _erc20Token, _seeds, _maxSlots, _sharedAmount, _duration + block.timestamp, _mintsNFTs);
//         addressToPromotions[_owner].push(seedIDs);
//         if (_mintsNFTs) {
//             receiptManager.setPromotionOwner(seedIDs, _owner); 
//         }
//         seedIDs += 1; 
//     }

    

//      function joinSeed(uint256 seedID, uint256 numOrders) public {
//         // Load seed into memory for efficient access
//         Seed memory seed = Seeds[seedID];
//         uint256 numParticipants = promotionIDToReceiptIDs[seedID].length;

//         if (numParticipants >= seed.maxSlots ||  seed.endTime < block.timestamp) {
//             revert Promotion_Expired();
//         } 
//         // Adjust order number if exceeding max slots
//         else if (numParticipants + numOrders > seed.maxSlots) {
//             numOrders = seed.maxSlots - numParticipants; 
//         }

//         // Determine seeded and unseeded participants
//         uint256 availableSeededSlots = seed.numSeeds > numParticipants
//             ? seed.numSeeds - numParticipants
//             : 0;
//         uint256 seededParticipants = numOrders > availableSeededSlots
//             ? availableSeededSlots
//             : numOrders;
//         uint256 unseededParticipants = numOrders - seededParticipants;

//         uint256 initialReceiptID;
//         if (seed.mintsNFTs) {
//             // Mint receipts and log details
//             initialReceiptID = receiptManager.mintReceipts(
//                 msg.sender,
//                 seedID, 
//                 numParticipants+1, 
//                 numOrders
//             );
//         } else {
//             initialReceiptID = receiptManager.incrementReceiptIDs(numOrders);
//         }

//         if (seededParticipants != 0) {
//             emit SeedReceiptsMinted(
//                 msg.sender,
//                 seedID,
//                 numParticipants + 1,
//                 initialReceiptID,
//                 true,
//                 seededParticipants
//             );
//         }
//         if (unseededParticipants != 0) {
//             emit SeedReceiptsMinted(
//                 msg.sender,
//                 seedID,
//                 numParticipants + 1 + seededParticipants,
//                 initialReceiptID + seededParticipants,
//                 false,
//                 unseededParticipants
//             );
//         }

//         for (uint256 i = 0; i < numOrders; ++i) {
//             uint256 receiptID = initialReceiptID + i;

//             // Populate SeedReceipts
//             SeedReceipts[receiptID] = SeedReceipt({
//                 seedID: seedID,
//                 redeemedAmount:  0, 
//                 seeded: (i < seededParticipants)
//             });

//             // Directly push to storage array
//             promotionIDToReceiptIDs[seedID].push(receiptID);

//             // Handle unminted receipt ownership
//             if (!seed.mintsNFTs) {
//                 unmintedReceiptsToOwners[receiptID] = msg.sender;
//             }
//         }

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
//             Seeds[seedID].earnedAmount += sharedAmount - commissionOnShared;
//         }

//         // Update earned commissions
//         earnedCommissions[seed.erc20Token] += totalCommission;

//         // Perform ERC20 transfers (unchanged)
//         IERC20(seed.erc20Token).transferFrom(
//             msg.sender,
//             address(this),
//             sharedAmount + amountToSeller
//         );
//         console.log(sharedAmount + amountToSeller);

//         IERC20(seed.erc20Token).transfer(
//             promotionsManager.getReceiverAddress(seed.owner, seed.erc20Token),
//             amountToSeller - commissionOnSeller
//         );
//         console.log(amountToSeller - commissionOnSeller);
//     }

//     // function seedRedeemableAmount(uint256 seedID) public view returns (uint256) {
//     //     Seed storage seed = Seeds[seedID];
//     //     return seed.earnedAmount/seed.numSeeds; 
//     // }

//     function redeemSeedReceipts(uint256[] calldata receiptIDs) external {
//         uint256 redeemableAmount; 
//         address erc20Token = Seeds[SeedReceipts[receiptIDs[0]].seedID].erc20Token; //erc20 address of the first token
//         for(uint256 i =0; i < receiptIDs.length; i++) {
//             SeedReceipt memory seedReceipt = SeedReceipts[receiptIDs[i]];
//             Seed storage seed = Seeds[seedReceipt.seedID];
//             require(erc20Token == seed.erc20Token, "Invalid"); 
//             if(seed.mintsNFTs) {
//                 require((receiptManager.ownerOf(receiptIDs[i]) == msg.sender), "Not owned");
//             }
//             else {
//                 require((unmintedReceiptsToOwners[receiptIDs[i]] == msg.sender), "Not owned");
//             }
//             if(seedReceipt.seeded == true) {
//                 uint256 seedRedeemable = seed.earnedAmount/seed.numSeeds;
//                 if(seedReceipt.redeemedAmount < seedRedeemable) {
//                     uint256 additionalRedeemable = seedRedeemable - seedReceipt.redeemedAmount;
//                     SeedReceipts[receiptIDs[i]].redeemedAmount = seedRedeemable;
//                     redeemableAmount += additionalRedeemable; 
//                     emit SeedReceiptRedeemed(receiptIDs[i], seedReceipt.seedID, additionalRedeemable);
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


//     function cancelSeed(uint256 seedID) public {
//         Seed storage seed = Seeds[seedID];
//         if (!promotionsManager.isApprovedOperator(msg.sender, seed.owner)) {
//             revert NotApproved(); 
//         }
//         if (seed.endTime > block.timestamp && promotionIDToReceiptIDs[seedID].length < seed.maxSlots) {
//             seed.maxSlots = promotionIDToReceiptIDs[seedID].length;
//             emit SeedCancelled(seedID, promotionIDToReceiptIDs[seedID].length);
//         }
//     }

//     function setRoyalty(uint256 promotionID, uint256 basisPoints) external override {
//         Seed storage seed = Seeds[promotionID]; 
//         if (!promotionsManager.isApprovedOperator(msg.sender, seed.owner)) {
//             revert NotApproved(); 
//         }
//         receiptManager.setRoyalty(promotionID, basisPoints);
//     }

//     function setPromotionURI(uint256 promotionID, string calldata newURIRoot) external override {
//         Seed storage seed =Seeds[promotionID]; 
//         if (!promotionsManager.isApprovedOperator(msg.sender, seed.owner)) {
//             revert NotApproved(); 
//         }
//         if (!seed.mintsNFTs) {
//             revert NotCustomURI(); 
//         }
//         if(bytes(receiptManager.customURIRoot(promotionID)).length != 0) {
//             revert URIAlreadSet();
//         }
//         receiptManager.modifyPromotionURI(promotionID, newURIRoot);
//     }
// }