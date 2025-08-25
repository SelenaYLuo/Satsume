// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error Promotion_Expired();
// error InvalidConfig(); 
// error NotApproved();

// event ListingCreated(address indexed owner, uint256 indexed ID, address indexed erc20Token, uint256 inventory, uint256 endTime, bool mintsNFTS);
// event SnowballCustodyRedeemed(uint256 indexed snowballID, uint256 redeemedAmount); 
// event ListingCancelled(uint256 indexed promotionID);
// event PlainSaleReceiptsMinted(address indexed buyer, uint256 indexed promotionID, uint256 firstParticipantNumber, uint256 firstTokenID, uint256 numOrders);


// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./PromotionManagerv11.sol";

// contract PlainSaleManager is PromotionManager {
//     struct Listing {
//         uint256 inventory; 
//         uint256 endTime;
//         address owner; 
//         uint256 price; 
//         address erc20Token; 
//         bool mintReceipts; 
//     }
    
//     uint256 public plainSaleID = 1;
//     uint256 public constant MINIMUM_DURATION = 900; 
//     mapping(uint256 => Listing) public Listings;
//     mapping(uint256 => uint256) public receiptIDtoListingID; 
    
    

//     constructor(address _receiptManagerAddress, address _promotionsManagerAddress) { 
//         contractOwner = msg.sender; // Set the owner to the contract deployer
//         receiptManager = IReceiptManager(_receiptManagerAddress); 
//         receiptManagerAddress = _receiptManagerAddress;
//         promotionsManagerAddress = _promotionsManagerAddress;  
//         promotionsManager = IPromotionsManager(_promotionsManagerAddress);
//     }

//     function createListing(
//         uint256 _inventory,
//         uint256 _duration,
//         address _owner,
//         address _erc20Token,
//         uint256 _price, 
//         bool _mintReceipts
//     ) public {
//         if (_duration < MINIMUM_DURATION ) {
//             revert InvalidConfig(); 
//         }
//         if (!promotionsManager.isApprovedOperator(msg.sender, _owner)) {
//             revert NotApproved(); 
//         }

//         // Initialize a new snowball contract and store it in storage
//         Listing storage listing = Listings[plainSaleID];
//         listing.inventory = _inventory;
//         listing.price = _price;
//         listing.owner = payable(_owner);
//         listing.endTime = block.timestamp +_duration;
//         listing.erc20Token = _erc20Token;
//         listing.mintReceipts = _mintReceipts;  

//         emit ListingCreated(_owner, plainSaleID, _erc20Token, _inventory, _duration + block.timestamp, _mintReceipts);
//         addressToPromotions[_owner].push(plainSaleID);
//         if (_mintReceipts) {
//             receiptManager.setPromotionOwner(plainSaleID, _owner); 
//         }
//         plainSaleID += 1; 
//     }

//     function joinPromotion(uint256 promotionID, uint256 numOrders, uint256 orderID, address buyer) public override {
//         Listing storage listing = Listings[promotionID];
//         uint256 numParticipants = promotionIDToReceiptIDs[promotionID].length;
//         address erc20Token = listing.erc20Token;

//         if (listing.inventory == 0 ||  listing.endTime < block.timestamp) {
//             revert Promotion_Expired();
//         } 
//         // Adjust order number if exceeding max slots
//         else if (numOrders > listing.inventory) {
//             numOrders = listing.inventory; 
//         }
//         listing.inventory -= numOrders; 

//         // Calculate commission
//         uint256 commissionAmount = (numOrders * listing.price) * commission / 10000;

//         // Update commissions and pay the owner
//         earnedCommissions[erc20Token] += commissionAmount;
//         IERC20(erc20Token).transferFrom(buyer, listing.owner, (numOrders * listing.price) - commissionAmount);
//         IERC20(erc20Token).transferFrom(buyer, address(this), commissionAmount);

//         uint256 initialReceiptID;
//         bool mintingReceipts = listing.mintReceipts; // Cache to memory for gas efficiency

//         if (mintingReceipts) {
//             initialReceiptID = receiptManager.mintReceipts(buyer, promotionID, numParticipants + 1, numOrders);
//         } else {
//             initialReceiptID = receiptManager.incrementReceiptIDs(numOrders);
//         }

//         // Process all receipt IDs in a single loop
//         for (uint256 i = 0; i < numOrders; i++) {
//             uint256 currentReceiptID = initialReceiptID + i;
            
//             // Common operations for both branches
//             receiptIDtoListingID[currentReceiptID] = promotionID;
//             promotionIDToReceiptIDs[promotionID].push(currentReceiptID);
            
//             // Branch-specific operation
//             if (!mintingReceipts) {
//                 unmintedReceiptsToOwners[currentReceiptID] = buyer;
//             }
//         }
//         emit PlainSaleReceiptsMinted(
//             buyer, 
//             promotionID, 
//             numParticipants + 1, 
//             initialReceiptID, 
//             numOrders
//         );
//     }

//     function setRoyalty(uint256 promotionID, uint256 basisPoints) external override {
//         Listing storage listing = Listings[promotionID]; 
//         if (!promotionsManager.isApprovedOperator(msg.sender, listing.owner)) {
//             revert NotApproved(); 
//         }
//         receiptManager.setRoyalty(promotionID, basisPoints);
//     }

//     function setPromotionURI(uint256 promotionID, string calldata newURIRoot) external override {
//         Listing storage listing = Listings[promotionID]; 
//         if (!promotionsManager.isApprovedOperator(msg.sender, listing.owner)) {
//             revert NotApproved(); 
//         }
//         if (!listing.mintReceipts) {
//             revert NotCustomURI(); 
//         }
//         if(bytes(receiptManager.customURIRoot(promotionID)).length != 0) {
//             revert URIAlreadSet();
//         }
//         receiptManager.modifyPromotionURI(promotionID, newURIRoot);
//     }

//     function updateInventory(uint256 promotionID, uint256 newInventory) public {
//         Listing storage listing =Listings[promotionID]; 
//         if (!promotionsManager.isApprovedOperator(msg.sender, listing.owner)) {
//             revert NotApproved(); 
//         }
//         if(listing.endTime != 0 && newInventory > listing.inventory) {
//             listing.inventory = newInventory; 
//         }
//     }

//     function updatePrice(uint256 promotionID, uint256 newPrice) public {
//         Listing storage listing =Listings[promotionID]; 
//         if (!promotionsManager.isApprovedOperator(msg.sender, listing.owner)) {
//             revert NotApproved(); 
//         }
//         if(listing.endTime != 0) {
//             listing.price = newPrice; 
//         }
//     }

//     function updateEndTime(uint256 promotionID, uint256 newEndTime) public {
//         Listing storage listing =Listings[promotionID]; 
//         if (!promotionsManager.isApprovedOperator(msg.sender, listing.owner)) {
//             revert NotApproved(); 
//         }
//         if(listing.endTime != 0 && newEndTime > block.timestamp) {
//             listing.endTime = newEndTime; 
//         }
//     }

//     //set the end time to zero to indiciate the listing is cancelled
//     function cancelListing(uint256 promotionID) public {
//         Listing storage listing =Listings[promotionID]; 
//         if (!promotionsManager.isApprovedOperator(msg.sender, listing.owner)) {
//             revert NotApproved(); 
//         }
//         listing.endTime = 0; 
//         emit ListingCancelled(promotionID);
//     }
// }