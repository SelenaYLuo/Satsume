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

// error TokenDoesNotExist(); 

// event PromotionURIModified(uint256 promotionID, string nameRoot, string imageRoot, string imageFileType, bool appendParticipantNumber, bool dynamicImage);
// event PromotionURICustomized(uint256 promotionID, string customURIRoot);


// contract ReceiptManager is ERC721, ERC721Enumerable, IERC2981 {
//     using Strings for uint256;
//     mapping(uint256 => uint256[]) promotionIDToTokens;

//     enum URIType {
//         Default,
//         Modified,
//         Customized 
//     }

//     address contractOwner;
//     string defaultURI;
//     // Mappings to store receipts by token ID
//     mapping(uint256 => URIType) public promotionURIs; 
//     mapping(uint256 => ModifiedURI) public modifiedURIs; 
//     mapping(uint256 => string) public customURIRoot; 
//     mapping(uint256 => address) public royaltyReceiver; 

//     struct ModifiedURI {
//         string modifiedNameRoot;
//         bool modifiedNameAppendNumber; 
//         bool dynamicImage; 
//         string modifiedImageRoot;
//         string dynamicImageType;
//     }

//     struct TokenContext {
//         uint256 promotionID;
//         uint256 participantNumber;
//     }

//     mapping(uint256 => TokenContext) public tokenContexts;
//     address[] approvedCallers; 
//     mapping(uint256 => uint256) public royaltyBasisPoints; 
//     string defaultImageURL; 


//     //Modifier to restrict usage to the approved callers
//     modifier onlyApprovedCallers() {
//         bool isApproved = false;
//         for (uint256 i = 0; i < approvedCallers.length; i++) {
//             if (approvedCallers[i] == msg.sender) {
//                 isApproved = true;
//                 break;
//             }
//         }
//         require(isApproved, "Not an approved caller");
//         _;
//     }

//     //Modifier to restrict usage to the contract owner
//     modifier onlyOwner() {
//         require(msg.sender == contractOwner, "Not Authorized");
//         _;
//     }

//     // Constructor to set the name and symbol of the ERC-721 token
//     constructor() ERC721("ReceiptNFT", "RPT") {
//         contractOwner = msg.sender;
//     }

//     function addApprovedCaller(address _toApprove) external onlyOwner {
//         approvedCallers.push(_toApprove); 
//     }

//     function removeApprovedCaller(address _toRemove) external onlyOwner {
//         for (uint256 i = 0; i < approvedCallers.length; i++) {
//             if (approvedCallers[i] == _toRemove) {
//                 // Swap the element to be removed with the last element
//                 approvedCallers[i] = approvedCallers[approvedCallers.length - 1];
//                 // Remove the last element from the array
//                 approvedCallers.pop();
//                 return;
//             }
//         }
//         revert("Address not found in approved callers.");
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

//     function setRoyalty(uint256 promotionID, uint256 basisPoints, address receiver) external onlyApprovedCallers {
//         require(basisPoints <=10000, "Invalid"); //royalty over 100%
//         royaltyReceiver[promotionID] = receiver;
//         royaltyBasisPoints[promotionID] = basisPoints; 
//     }

//     function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
//         // Return the royalty receiver and amount (calculated based on sale price)
//         uint256 promotionID = tokenContexts[tokenId].promotionID;
//         receiver = royaltyReceiver[promotionID]; 
//         royaltyAmount = (salePrice * royaltyBasisPoints[promotionID]) / 10000;
//         return (receiver, royaltyAmount);
//     }
    
//     function mintReceipts(address to, uint256 promotionID, uint256 participantNumber, uint256 numTokens) external onlyApprovedCallers returns(uint256 ) {
//         uint256 initialID = totalSupply() +1 ; 
//         for (uint256 i = 0; i < numTokens; i++) {
//             _mint(to, initialID + i);
//             TokenContext storage tokenContext = tokenContexts[initialID + i];
//             tokenContext.promotionID = promotionID;
//             tokenContext.participantNumber = participantNumber +i;
//             promotionIDToTokens[promotionID].push(initialID + i);
//             // if(promotionType == 0) {
//             //     snowballIDToTokens[promotionID].push(initialID + i);
//             // }
//             // else if(promotionType == 1) {
//             //     seedIDToTokens[promotionID].push(initialID + i);
//             // }
//             // else if(promotionType == 2) {
//             //     drawingIDToTokens[promotionID].push(initialID + i);
//             // }
//         }
//         return initialID;
//     }

//     function getTokenIDsInRange(
//         uint256 promotionID,
//         uint256 startIndex,
//         uint256 endIndex
//     ) external view returns (uint256[] memory) {
//         require(endIndex >= startIndex, "Invalid index range");
//         uint256 arrayLength = promotionIDToTokens[promotionID].length;
//         require(endIndex < arrayLength, "End index out of bounds");

//         uint256 rangeLength = endIndex - startIndex + 1;
//         uint256[] memory result = new uint256[](rangeLength);

//         for (uint256 i = 0; i < rangeLength; i++) {
//             result[i] = promotionIDToTokens[promotionID][startIndex + i];
//         }

//         return result;
//     }

//     function getPromotionTokens(uint256 promotionID) external view returns(uint256[] memory) {
//         return promotionIDToTokens[promotionID]; 
//     }
    
//     function modifyPromotionURI(uint256 promotionID, string calldata _modifiedNameRoot, bool _modifiedNameAppendNumber, bool _dynamicImageBool, string calldata _modifiedImageRoot, string calldata _dynamicImageType) external onlyApprovedCallers {
//         ModifiedURI storage modifiedURI = modifiedURIs[promotionID]; 
//         require(promotionURIs[promotionID] == URIType.Default, "Already Set"); //Only default URIs can be set (set only once)
//         modifiedURI.modifiedNameRoot = _modifiedNameRoot;
//         modifiedURI.modifiedNameAppendNumber = _modifiedNameAppendNumber;
//         modifiedURI.dynamicImage = _dynamicImageBool;
//         modifiedURI.modifiedImageRoot = _modifiedImageRoot;
//         if(_dynamicImageBool) {
//             modifiedURI.dynamicImageType = _dynamicImageType; 
//         }
//         promotionURIs[promotionID] = URIType.Modified; 
//         emit PromotionURIModified(promotionID, _modifiedNameRoot, _modifiedImageRoot, _dynamicImageType, _modifiedNameAppendNumber, _dynamicImageBool);
//     }

//     function customizePromotionURI(uint256 promotionID, string calldata _customURIRoot) external onlyApprovedCallers {
//         require(promotionURIs[promotionID] == URIType.Default, "Already Set"); //Only default URIs can be set (set only once)
//         customURIRoot[promotionID] = _customURIRoot; 
//         promotionURIs[promotionID] = URIType.Customized; 
//         emit PromotionURICustomized(promotionID, _customURIRoot);
//     }

//     function setDefaultImageURL(string calldata newDefault) external onlyOwner {
//         require(msg.sender == contractOwner, "Not Owner");
//         defaultImageURL = newDefault;
//     }
    
//     function tokenURI(uint256 tokenId) public view override returns (string memory) {
//         TokenContext storage tokenContext = tokenContexts[tokenId];
//         uint256 promotionID = tokenContext.promotionID;
//         uint256 participantNumber = tokenContext.participantNumber; 

//         if(promotionID ==0) {
//             revert TokenDoesNotExist(); 
//         }

//         URIType uriType = promotionURIs[promotionID];
//         string memory receiptName;
//         string memory imageFieldValue;

//         // Construct base receipt name
//         if (uriType == URIType.Default) {
//             receiptName = string(abi.encodePacked(
//                 "Satsume Promotion #", 
//                 uint2str(promotionID), 
//                 " Receipt #", 
//                 uint2str(participantNumber)
//             ));
//             imageFieldValue = defaultImageURL;
//         } else if (uriType == URIType.Modified) {
//             ModifiedURI storage modifiedURI = modifiedURIs[promotionID];
//             receiptName = modifiedURI.modifiedNameAppendNumber
//                 ? string(abi.encodePacked(modifiedURI.modifiedNameRoot, " #", uint2str(participantNumber)))
//                 : modifiedURI.modifiedNameRoot;
//             imageFieldValue = modifiedURI.dynamicImage
//                 ? string(abi.encodePacked(modifiedURI.modifiedImageRoot, "/", uint2str(participantNumber), ".", modifiedURI.dynamicImageType))
//                 : modifiedURI.modifiedImageRoot;
//         } else if (uriType == URIType.Customized) {
//             // Return the custom metadata directly
//             return string(abi.encodePacked(customURIRoot[promotionID], "/", uint2str(participantNumber), ".json"));
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
// }
