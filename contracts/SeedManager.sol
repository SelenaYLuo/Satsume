// pragma solidity ^0.8.24;

// error Promotion_Expired();
// error InvalidConfig(); 
// error NotApproved();
// error DoesNotExist();
// error WrongPromotionManager();
// error NotCustomURI();
// error URIAlreadSet();

// event SeedCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 seeds, uint256 maxSlots, uint256 sharedAmount, uint256 endTime, bool mintsNFTs);
// event SeedCancelled(uint256 indexed promotionID, uint256 numberOfParticipants); 
// event SeedReceiptsMinted(address indexed joiner, uint256 promotionID, uint256 firstParticipantNumber, uint256  firstTokenID, bool seeded, uint256 numTickets);
// event SeedReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 redeemedAmount); 

// import "hardhat/console.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./PromotionManagerv8.sol";

// contract SeedManager is PromotionManager {
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
//         bool mintsNFTs; 
//     }

//     struct SeedReceipt {
//         uint256 seedID;
//         uint256 redeemedAmount;
//         uint256 participantNumber; 
//         bool seeded;
//     }


//     uint256 public seedIDs = type(uint256).max / 10 + 1;
//     uint256 public constant MINIMUM_DURATION = 900; 
//     mapping(uint256 => Seed) public Seeds;
//     mapping(uint256 => SeedReceipt) public SeedReceipts;

//     constructor(address _receiptManagerAddress) { 
//         owner = msg.sender; // Set the owner to the contract deployer
//         bank = payable(owner);
//         receiptManager = IReceiptManager(_receiptManagerAddress); 
//         receiptManagerAddress = _receiptManagerAddress;
//     }

//     function createSeed(uint256 _seeds, uint256 _maxSlots, uint256 _price, uint256 _duration, uint256 _sharedAmount, address _owner, address _erc20Token, bool _mintsNFTs) public {
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
//         seed.mintsNFTs = _mintsNFTs; 

//         emit SeedCreated(_owner, seedIDs, _erc20Token, _seeds, _maxSlots, _sharedAmount, _duration + block.timestamp, _mintsNFTs);
//         addressToPromotions[_owner].push(seedIDs);
//         receiptManager.setPromotionOwner(seedIDs, _owner); 
//         seedIDs += 1; 
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

//         // Mint  receipts and log details
//         uint256 initialTokenID = receiptManager.mintReceipts(
//             msg.sender,
//             address(this),
//             numOrders
//         );
//         if(seededParticipants !=0) {
//             emit SeedReceiptsMinted(msg.sender, seedID, seed.numParticipants +1, initialTokenID, true, seededParticipants);
//         }
//         if(unseededParticipants !=0) {
//             emit SeedReceiptsMinted(msg.sender, seedID, seed.numParticipants + 1 + seededParticipants, initialTokenID + seededParticipants, false, unseededParticipants);
//         }
        

//         for (uint256 i = 0; i < numOrders; ++i) {
//             SeedReceipt storage seedReceipt = SeedReceipts[initialTokenID + i];
//             seedReceipt.seedID = seedID;
//             seedReceipt.seeded = (i < seededParticipants);
//             seedReceipt.participantNumber = seed.numParticipants + 1 +i; 
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

//     function cancelPromotion(uint256 promotionID) public {
//         Seed storage seed = Seeds[promotionID];
//         if (msg.sender != seed.owner && !approvedOperators[seed.owner][msg.sender]) {
//             revert NotApproved(); 
//         }
//         if (seed.endTime > block.timestamp && seed.numParticipants < seed.maxSlots) {
//             seed.maxSlots = seed.numParticipants;
//             emit SeedCancelled(promotionID, seed.numParticipants);
//         }
//     }

//     function getReceiptInfo(uint256 receiptID) public view override returns(uint256 promotionID, uint256 participantNumber) {
//         SeedReceipt storage seedReceipt = SeedReceipts[receiptID]; 
//         return(seedReceipt.seedID, seedReceipt. participantNumber); 
//     }

//     function setRoyalty(uint256 promotionID, uint256 basisPoints) external override {
//         Seed storage seed = Seeds[promotionID]; 
//         if (msg.sender != seed.owner && !approvedOperators[seed.owner][msg.sender]) {
//             revert NotApproved(); 
//         }
//         receiptManager.setRoyalty(promotionID, basisPoints);
//     }

//     function setPromotionURI(uint256 promotionID, string calldata newURIRoot) public override {
//         Seed storage seed =Seeds[promotionID]; 
//         if (msg.sender != seed.owner && !approvedOperators[seed.owner][msg.sender]) {
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