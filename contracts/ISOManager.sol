// //SPDX-License-Identifier: UNLICENSED
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
// import "../interfaces/IPromotionManager.sol";
// import "../interfaces/IPromotionsManager.sol";

// error TokenDoesNotExist();
// error NotApproved();

// contract ISOManager is ERC721, IERC2981 {
//     address public contractOwner;
//     using Strings for uint256;
//     struct ISO {
//         uint256 numTokens;
//         uint256 revShare;
//         uint256 price;
//         uint256 minted;
//         mapping(address => uint256) redeemableAmounts;
//         //address store;
//         address erc20Token;
//     }
//     struct ShareContext {
//         address store;
//         uint256 shareNumber;
//         mapping(address => uint256) redeemedAmounts;
//     }

//     mapping(address => ISO) public ISOs;
//     mapping(address => uint256[]) public addressToTokenIDs;
//     mapping(uint256 => ShareContext) public ShareContexts;
//     uint256 tokenIDs;
//     bool openISOs = false;
//     IPromotionsManager public promotionsManager;
//     address public promotionsManagerAddress;

//     //Modifier to restrict usage to the contract owner
//     modifier onlyOwner() {
//         require(msg.sender == contractOwner, "Not Authorized");
//         _;
//     }

//     //Modifier to allow ISOs
//     modifier allowedISOs() {
//         require(openISOs == true, "ISOs not allowed");
//         _;
//     }

//     modifier onlyApprovedOperators(address parentAccount) {
//         require(
//             promotionsManager.isApprovedOperator(msg.sender, parentAccount),
//             "Not Approved"
//         );
//         _;
//     }

//     // Constructor to set the name and symbol of the ERC-721 token
//     constructor() ERC721("ISOTokens", "ISO") {
//         contractOwner = msg.sender;
//     }

//     function setOwner(address payable newOwner) external onlyOwner {
//         contractOwner = payable(newOwner);
//     }

//     function allowISOs() public onlyOwner {
//         openISOs = true;
//     }

//     function createISO(
//         uint256 _numTokens,
//         uint256 _revShare,
//         uint256 _price,
//         address _erc20Token
//     ) public allowedISOs {
//         require(ISOs[msg.sender].numTokens == 0, "already ISO");
//         require(_numTokens > 0 && _numTokens * _revShare <= 10000);

//         // Initialize a new drawing contract and store it in storage
//         ISO storage iso = ISOs[msg.sender];
//         iso.numTokens = _numTokens;
//         iso.revShare = _revShare;
//         iso.price = _price;
//         iso.erc20Token = _erc20Token;
//     }

//     function buyISO(address store, uint256 numShares) public allowedISOs {
//         ISO storage iso = ISOs[store];
//         require(iso.numTokens > 0, "ISO doesn't exist"); // Check ISO exists
//         require(numShares > 0, "Cannot buy 0 shares");
//         if (iso.minted + numShares > iso.numTokens) {
//             numShares = iso.numTokens - iso.minted;
//         }

//         // Calculate total price with overflow check
//         uint256 totalPrice = numShares * iso.price;
//         require(totalPrice / iso.price == numShares, "Overflow detected");

//         // Transfer payment
//         IERC20(iso.erc20Token).transferFrom(msg.sender, store, totalPrice);

//         // Mint tokens and set context
//         uint256 startTokenId = tokenIDs;
//         for (uint256 i = 0; i < numShares; i++) {
//             uint256 tokenId = startTokenId + i;
//             _mint(msg.sender, tokenId);
//             addressToTokenIDs[store].push(tokenId);
//             ShareContexts[tokenId].shareNumber = addressToTokenIDs[store]
//                 .length;
//             ShareContexts[tokenId].store = store;
//         }

//         // Update state
//         tokenIDs += numShares;
//         iso.minted += numShares; // Track minted tokens
//     }

//     function payStore(
//         address store,
//         uint256 toStore,
//         uint256 commission,
//         address erc20Token,
//         address payor
//     ) public {
//         if (ISOs[store].numTokens == 0 || !openISOs) {
//             //no active ISO liabilities
//             IERC20(erc20Token).transferFrom(payor, store, toStore);
//             IERC20(erc20Token).transferFrom(payor, address(this), commission);
//         } else {
//             //Separate amounts for storefronts and store shareholders + commissions
//             uint256 redeemable = (toStore * ISOs[store].revShare) / 10000;
//             uint256 toOwner = toStore - redeemable * ISOs[store].numTokens;
//             IERC20(erc20Token).transferFrom(payor, store, toOwner);
//             IERC20(erc20Token).transferFrom(
//                 payor,
//                 address(this),
//                 redeemable * ISOs[store].numTokens + commission
//             );
//             ISOs[store].redeemableAmounts[erc20Token] += redeemable;
//         }
//     }

//     function redeemDividends(
//         uint256[] calldata tokenIDArray, // Array of token IDs
//         address[] calldata erc20Tokens // Array of ERC20 tokens
//     ) public {
//         for (uint256 j = 0; j < tokenIDArray.length; j++) {
//             uint256 tokenID = tokenIDArray[j];

//             // Validate token ownership
//             require(ownerOf(tokenID) == msg.sender, "Not owner of token");

//             ShareContext storage shareContext = ShareContexts[tokenID];
//             ISO storage iso = ISOs[shareContext.store];

//             // Process each ERC20 token for dividends
//             for (uint256 i = 0; i < erc20Tokens.length; i++) {
//                 address tokenAddress = erc20Tokens[i];

//                 // Calculate redeemable amount
//                 uint256 redeemable = iso.redeemableAmounts[tokenAddress] -
//                     shareContext.redeemedAmounts[tokenAddress];

//                 if (redeemable > 0) {
//                     // Transfer dividends
//                     IERC20(tokenAddress).transfer(msg.sender, redeemable);

//                     // Update redemption tracking
//                     shareContext.redeemedAmounts[tokenAddress] = iso
//                         .redeemableAmounts[tokenAddress];
//                 }
//             }
//         }
//     }

//     string public defaultURIRoot = "amazon.com/";
//     // Mappings to store receipts by token ID
//     mapping(address => string) public customURIRoot;
//     mapping(address => address) public royaltyReceiver;
//     mapping(address => uint16) public royaltyBasisPoints;

//     function setCustomURIRoot(string calldata newRoot, address store) public {
//         if (!promotionsManager.isApprovedOperator(msg.sender, store)) {
//             revert NotApproved();
//         }
//         require(bytes(customURIRoot[store]).length == 0, "Aready Set");
//         customURIRoot[store] = newRoot;
//     }

//     function tokenURI(
//         uint256 tokenID
//     ) public view override returns (string memory) {
//         ShareContext storage shareContext = ShareContexts[tokenID];

//         // Check if the tokenID is valid
//         if (shareContext.store == address(0)) {
//             revert TokenDoesNotExist();
//         }

//         // Retrieve the custom URI root for the promotion
//         string memory uriRoot = customURIRoot[shareContext.store];

//         // If no custom URI is set, use the default URI
//         if (bytes(uriRoot).length == 0) {
//             //return string(abi.encodePacked(defaultURIRoot, "/", uint2str(tokenID), ".json"));
//             return
//                 string(
//                     abi.encodePacked(
//                         defaultURIRoot,
//                         "/",
//                         uint2str(shareContext.shareNumber),
//                         ".json"
//                     )
//                 );
//         } else {
//             // Construct the custom URI using participantNumber
//             return
//                 string(
//                     abi.encodePacked(
//                         uriRoot,
//                         "/",
//                         uint2str(shareContext.shareNumber),
//                         ".json"
//                     )
//                 );
//         }
//     }

//     function supportsInterface(
//         bytes4 interfaceId
//     ) public view override(ERC721, IERC165) returns (bool) {
//         return super.supportsInterface(interfaceId);
//     }

//     function setRoyalty(uint16 basisPoints, address store) external {
//         if (!promotionsManager.isApprovedOperator(msg.sender, store)) {
//             revert NotApproved();
//         }
//         require(basisPoints <= 10000, "Invalid"); //royalty over 100%
//         royaltyBasisPoints[store] = basisPoints;
//     }

//     function royaltyInfo(
//         uint256 tokenID,
//         uint256 salePrice
//     ) external view override returns (address receiver, uint256 royaltyAmount) {
//         ShareContext storage shareContext = ShareContexts[tokenID];
//         royaltyAmount =
//             (salePrice * royaltyBasisPoints[shareContext.store]) /
//             10000;
//         return (shareContext.store, royaltyAmount);
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

//     function setPromotionsManager(
//         address _promotionsManagerAddress
//     ) external onlyOwner {
//         promotionsManagerAddress = _promotionsManagerAddress;
//         promotionsManager = IPromotionsManager(_promotionsManagerAddress);
//     }
// }
