// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/interfaces/IERC2981.sol";
// import "@openzeppelin/contracts/utils/Base64.sol";
// import "@openzeppelin/contracts/utils/Strings.sol";
// import "hardhat/console.sol";
// import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// event SnowballReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 redeemedAmount); 
// event DrawingReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 redeemedAmount); 
// event SeedReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 redeemedAmount); 
// event PromotionURIModified(uint256 promotionID, string receiptName, string imageRoot, bool appendParticipantNumber, bool dynamicImage);
// event PromotionURICustomized(uint256 promotionID, string customURIRoot);



// // Interface for the USDC token contract
// // interface IERC20 {
// //     function transfer(
// //         address recipient,
// //         uint256 amount
// //     ) external returns (bool);

// //     function transferFrom(
// //         address from,
// //         address to,
// //         uint256 value
// //     ) external returns (bool);

// //     function balanceOf(address account) external view returns (uint256);
// // }

// // Interface for the PromotionManager contract
// interface IPromotionManager {
//     function reduceDrawingCustodyBalance(
//         uint256 promotionID,
//         uint256 amount
//     ) external;

//     function reduceSnowballCustodyBalance(
//         uint256 promotionID,
//         uint256 amount
//     ) external;

//     function reduceSeedCustodyBalance(
//         uint256 seedID,
//         uint256 reductionAmount
//     ) external;

//     function isOwner(
//         uint256 promotionID,
//         address possibleOwner
//     ) external view returns (bool);

//     function getSnowballPrice(
//         uint256 snowballID
//     ) external view returns (uint256);

//     function Drawings(
//         uint256 drawingId
//     )
//         external
//         view
//         returns (
//             uint256 maxSlots,
//             uint256 duration,
//             uint256 startTime,
//             uint256 price,
//             uint256 cohortSize,
//             uint256 rebateAmount,
//             uint256 custodyBalance,
//             address owner,
//             bool returnedCustody,
//             address erc20Token
//         );

//     function seedRedeemableAmount(
//         uint256 seedID
//     ) external view returns (uint256);

//     function getPromotionOwner(uint256 promotionID) external view returns (address);

// }

// contract ReceiptManager is ERC721, ERC721Enumerable, IERC2981 {
//     using Strings for uint256;
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

//     // Enum to keep track of the type of receipt
//     enum ReceiptType {
//         Snowball,
//         Drawing,
//         Seed
//     }

//     enum URIType {
//         Default,
//         Modified,
//         Customized 
//     }

//     uint256 mintedReceipts; 
//     address contractOwner;
//     address promotionManagerAddress;
//     string defaultURI;
//     // Mappings to store receipts by token ID
//     mapping(uint256 => SnowballReceipt) public snowballReceipts;
//     mapping(uint256 => DrawingReceipt) public drawingReceipts;
//     mapping(uint256 => SeedReceipt) public seedReceipts;
//     mapping(uint256 => uint256[]) public promotionToTokenIDs;
//        mapping(uint256 => uint256) public royaltyBasisPoints; 
//     mapping(uint256 => string) public promotionIDToModifiedName;
//     mapping(uint256 => bool) public modifiedNameAppendParticipantNumber; 
//     mapping(uint256 => bool) public promotionIDToDynamicImage; 
//     mapping(uint256 => string) public promotionIDToModifiedImageRoot;
//     mapping(uint256 => string) public promotionIDToModifiedImageType;
//     mapping(uint256 => string) public promotionIDToCustomRoot ;
//     mapping(uint256 => URIType) public promotionIDToURIType; 
//     mapping(uint256 => bool) public uriSet; 
//     string defaultImageURL; 

//     // Mapping to track which type of receipt corresponds to each token ID
//     mapping(uint256 => ReceiptType) public receiptTypes;

//     // Address of the PromotionManager contract
//     IPromotionManager public promotionManager;

//     //Modifier to restrict usage to the promotion manager
//     modifier onlyPromoManager() {
//         require(msg.sender == promotionManagerAddress, "Not Authorized");
//         _;
//     }

//     // Constructor to set the name and symbol of the ERC-721 token
//     constructor(address _promotionManagerAddress) ERC721("ReceiptNFT", "RPT") {
//         promotionManager = IPromotionManager(_promotionManagerAddress);
//         promotionManagerAddress = _promotionManagerAddress;
//         contractOwner = msg.sender;
//     }

//     function _update(
//         address to,
//         uint256 tokenId,
//         address auth
//     ) internal override(ERC721, ERC721Enumerable) returns (address) {
//         return super._update(to, tokenId, auth);
//     }

//     function _increaseBalance(
//         address account,
//         uint128 value
//     ) internal override(ERC721, ERC721Enumerable) {
//         super._increaseBalance(account, value);
//     }

//     function supportsInterface(
//         bytes4 interfaceId
//     ) public view override(ERC721, ERC721Enumerable, IERC165) returns (bool) {
//         return super.supportsInterface(interfaceId);
//     }

//     function setRoyalty(uint256 promotionID, uint256 basisPoints) external {
//         require(promotionManager.isOwner(promotionID, msg.sender), "Not Owner");
//         require(basisPoints <=10000, "Invalid"); //royalty over 100%
//         royaltyBasisPoints[promotionID] = basisPoints; 
//     }

//     function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
//         // Return the royalty receiver and amount (calculated based on sale price)
//         uint256 promotionID;
//         if(receiptTypes[tokenId] == ReceiptType.Snowball) {
//             promotionID = snowballReceipts[tokenId].promotionID;
//             receiver = promotionManager.getPromotionOwner(promotionID); 
//         }
//         else if (receiptTypes[tokenId] == ReceiptType.Drawing) {
//             promotionID = drawingReceipts[tokenId].promotionID;
//             receiver = promotionManager.getPromotionOwner(promotionID);
//         }
//         else if (receiptTypes[tokenId] == ReceiptType.Seed) {
//             promotionID = seedReceipts[tokenId].promotionID;
//             receiver = promotionManager.getPromotionOwner(promotionID);
//         }
//         royaltyAmount = (salePrice * royaltyBasisPoints[promotionID]) / 10000;
//         return (receiver, royaltyAmount);
//     }


//     // Function to mint multiple Snowball Receipts in a batch
//     function createSnowballReceipts(
//         address to,
//         uint256 promotionID,
//         uint256 startParticipantNumber,
//         uint256 effectivePricePaid,
//         address erc20TokenAddress,
//         uint256 numTickets
//     ) external onlyPromoManager returns (uint256[] memory) {
//         require(numTickets > 0, "Number of tickets must be greater than zero");

//         uint256[] memory mintedReceiptIDs = new uint256[](numTickets); // Array to store the minted receipt IDs
//         uint256 initialID = mintedReceipts +1 ; 

//         for (uint256 i = 0; i < numTickets; i++) {
//             // Create a new SnowballReceipt
//             snowballReceipts[initialID+i] = SnowballReceipt(
//                 promotionID,
//                 startParticipantNumber + i, // Increment the participant number for each ticket
//                 effectivePricePaid,
//                 erc20TokenAddress
//             );

//             // Mint the receipt to the user
//             _mint(to, initialID + i);

//             // Set the receipt type
//             receiptTypes[initialID +i] = ReceiptType.Snowball;

//             // Map the minted receipt to the promotion
//             promotionToTokenIDs[promotionID].push(initialID +i);

//             // Add the minted receipt ID to the array
//             mintedReceiptIDs[i] = initialID +i;
//         }

//         return mintedReceiptIDs; // Return the array of minted receipt IDs
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
//                 require((ownerOf(tokenId) == msg.sender), "Not owned");
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
//                 require((ownerOf(tokenId) == msg.sender), "Not owned");
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
//     function createSeedReceipts(
//         address to,
//         uint256 promotionID,
//         uint256 startParticipantNumber,
//         address erc20TokenAddress,
//         bool seeded,
//         uint256 numTickets
//     ) external onlyPromoManager returns (uint256[] memory) {
//         require(numTickets > 0, "Inv");

//         // Create an array to store the minted receipt IDs
//         uint256[] memory mintedReceiptIDs = new uint256[](numTickets);
//         uint256 initialID = mintedReceipts + 1; // Start ID for this batch

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

//             // Mint the token to the recipient
//             _mint(to, initialID + i);

//             // Map the minted receipt ID to the promotion
//             promotionToTokenIDs[promotionID].push(initialID + i);

//             // Add the minted receipt ID to the array
//             mintedReceiptIDs[i] = initialID + i;
//         }

//         // Update the global mintedReceipts counter
//         mintedReceipts += numTickets;

//         return mintedReceiptIDs; // Return the array of minted receipt IDs
//     }

//     function createSeedReceipt(
//         address to,
//         uint256 promotionID,
//         uint256 participantNumber,
//         address erc20TokenAddress,
//         bool seeded
//     ) external onlyPromoManager returns(uint256) {
//         mintedReceipts+=1; 
//         seedReceipts[mintedReceipts] = SeedReceipt(
//             promotionID,
//             participantNumber,
//             0,
//             seeded,
//             erc20TokenAddress
//         );
//         receiptTypes[mintedReceipts] = ReceiptType.Seed;
//         _mint(to, mintedReceipts);
//         promotionToTokenIDs[promotionID].push(mintedReceipts);
//         return mintedReceipts;
//     }

//     function createDrawingReceipt(
//         address to,
//         uint256 promotionID,
//         uint256 participantNumber,
//         address erc20TokenAddress,
//         uint256 numTickets
//     ) external onlyPromoManager returns (uint256[] memory) {
//         require(numTickets > 0, "Inv");

//         uint256[] memory receiptIDs = new uint256[](numTickets);

//         for (uint256 i = 0; i < numTickets; i++) {
//             uint256 receiptID = mintedReceipts;

//             // Create and store the DrawingReceipt
//             drawingReceipts[receiptID] = DrawingReceipt(
//                 promotionID,
//                 participantNumber + i, // Increment participant number for each ticket
//                 0,
//                 false,
//                 erc20TokenAddress
//             );

//             // Set receipt type
//             receiptTypes[receiptID] = ReceiptType.Drawing;

//             // Mint the token
//             _mint(to, receiptID);

//             // Map receipt ID to promotion
//             promotionToTokenIDs[promotionID].push(receiptID);

//             // Store the receipt ID in the array
//             receiptIDs[i] = receiptID;

//             // Increment mintedReceipts for the next receipt
//             mintedReceipts++;
//         }

//         return receiptIDs;
//     }

//     function nameDrawingWinner(
//         uint256 tokenId,
//         uint256 winningAmount
//     ) external onlyPromoManager {
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

//     function modifyPromotionURI(
//         uint256 promotionID, 
//         string calldata receiptName, 
//         bool appendParticipantNumber, 
//         string calldata imageRoot, 
//         bool dynamicImage
//     ) public {
//         // Ensure caller is the owner of the promotion
//         require(promotionManager.isOwner(promotionID, msg.sender), "Not Owner");

//         // Ensure the URI has not already been set
//         require(!uriSet[promotionID], "Already Set");

//         // Set URI type to Modified
//         promotionIDToURIType[promotionID] = URIType.Modified;

//         // Update the mappings for modified name and images
//         promotionIDToModifiedName[promotionID] = receiptName;
//         modifiedNameAppendParticipantNumber[promotionID] = appendParticipantNumber;
//         promotionIDToModifiedImageRoot[promotionID] = imageRoot;
//         promotionIDToDynamicImage[promotionID] = dynamicImage;

//         // Mark this promotion URI as set
//         uriSet[promotionID] = true;

//         //Emit Event
//         emit PromotionURIModified(promotionID, receiptName, imageRoot, appendParticipantNumber, dynamicImage);
//     }

    

//     // function customizePromotionURI(
//     //     uint256 promotionID, 
//     //     string calldata customURIRoot
//     // ) public {
//     //     // Ensure caller is the owner of the promotion
//     //     require(promotionManager.isOwner(promotionID, msg.sender), "Not Owner");

//     //     // Ensure the URI has not already been set
//     //     require(!uriSet[promotionID], "Already Set");

//     //     // Set URI type to Customized
//     //     promotionIDToURIType[promotionID] = URIType.Customized;

//     //     // Update the mapping for the custom URI root
//     //     promotionIDToCustomRoot[promotionID] = customURIRoot;

//     //     // Mark this promotion URI as set
//     //     uriSet[promotionID] = true;

//     //     //Emit Event
//     //     emit PromotionURICustomized(promotionID, customURIRoot); 
//     // }

//     function tokenURI(uint256 tokenId) public view override returns (string memory) {
//         ReceiptType receiptType = receiptTypes[tokenId];
//         uint256 promotionID;
//         uint256 participantNumber; 

//         // Determine promotionID and participantNumber based on receipt type
//         if (receiptType == ReceiptType.Snowball) {
//             promotionID = snowballReceipts[tokenId].promotionID;
//             participantNumber = snowballReceipts[tokenId].participantNumber;
//         } else if (receiptType == ReceiptType.Drawing) {
//             promotionID = drawingReceipts[tokenId].promotionID;
//             participantNumber = drawingReceipts[tokenId].participantNumber;
//         } else {
//             promotionID = seedReceipts[tokenId].promotionID;
//             participantNumber = seedReceipts[tokenId].participantNumber;
//         }

//         URIType uriType = promotionIDToURIType[promotionID];
//         string memory receiptName;
//         string memory imageFieldValue;

//         // Construct base receipt name
//         if (uriType == URIType.Default) {
//             receiptName = string(abi.encodePacked(
//                 "Satsume ", 
//                 receiptType == ReceiptType.Snowball ? "Snowball #" : 
//                 receiptType == ReceiptType.Drawing ? "Drawing #" : "Seed #", 
//                 uint2str(promotionID), 
//                 " Receipt #", 
//                 uint2str(participantNumber)
//             ));
//             imageFieldValue = defaultImageURL;
//         } else if (uriType == URIType.Modified) {
//             receiptName = modifiedNameAppendParticipantNumber[promotionID]
//                 ? string(abi.encodePacked(promotionIDToModifiedName[promotionID], " #", uint2str(participantNumber)))
//                 : promotionIDToModifiedName[promotionID];
//             imageFieldValue = promotionIDToDynamicImage[promotionID]
//                 ? string(abi.encodePacked(promotionIDToModifiedImageRoot[promotionID], "/", uint2str(participantNumber), ".", promotionIDToModifiedImageType[promotionID]))
//                 : promotionIDToModifiedImageRoot[promotionID];
//         } else if (uriType == URIType.Customized) {
//             // Return the custom metadata directly
//             return string(abi.encodePacked(promotionIDToCustomRoot[promotionID], "/", uint2str(participantNumber), ".json"));
//         }

//         // Return JSON metadata
//         return string(
//             abi.encodePacked(
//                 '{"name": "', receiptName,
//                 '", "image": "', imageFieldValue, '"}'
//             )
//         );
//     }

//     // Convert uint256 to string
//     function uint2str(uint256 _i) internal pure returns (string memory) {
//         if (_i == 0) {
//             return "0";
//         }
//         uint256 j = _i;
//         uint256 len;
//         while (j != 0) {
//             len++;
//             j /= 10;
//         }
//         bytes memory bstr = new bytes(len);
//         while (_i != 0) {
//             bstr[--len] = bytes1(uint8(48 + (_i % 10)));
//             _i /= 10;
//         }
//         return string(bstr);
//     }

//     // function TokensOfPromotions(
//     //     uint256 promotionsID
//     // ) public view returns (uint256[] memory) {
//     //     return promotionToTokenIDs[promotionsID];
//     // }

//     // function _exists(uint256 tokenId) internal view returns (bool) {
//     //     return _ownerOf(tokenId) != address(0);
//     // }

//     // function setDefaultReceiptImage(string calldata imageURL) external {
//     //     require(msg.sender == contractOwner, "Not Owner");
//     //     defaultImageURL = imageURL;
//     // }
// }
