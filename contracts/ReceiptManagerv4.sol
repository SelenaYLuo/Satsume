//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPromotionManager.sol";

error TokenDoesNotExist(); 

event PromotionURIModified(uint256 promotionID, string nameRoot, string imageRoot, string imageFileType, bool appendParticipantNumber, bool dynamicImage);
event PromotionURICustomized(uint256 promotionID, string customURIRoot);


contract ReceiptManager is ERC721, IERC2981 {
    using Strings for uint256;
    struct TokenContext {
        uint256 promotionID;
        uint256 participantNumber;
    }

    mapping(uint256 => TokenContext) public tokenContexts;

    address public contractOwner;
    string public defaultURIRoot = "amazon.com/";
    // Mappings to store receipts by token ID
    mapping(uint256 => string) public customURIRoot; 
    mapping(uint256 => address) public royaltyReceiver; 
    uint256 public receiptIDs;
    address[] public approvedCallers; 
    mapping(uint256 => uint256) public royaltyBasisPoints; 
    mapping(uint256  => address) public promotionOwners;

    //Modifier to restrict usage to the approved callers
    modifier onlyApprovedCallers() {
        bool isApproved = false;
        for (uint256 i = 0; i < approvedCallers.length; i++) {
            if (approvedCallers[i] == msg.sender) {
                isApproved = true;
                break;
            }
        }
        require(isApproved, "Not an approved caller");
        _;
    }

    //Modifier to restrict usage to the contract owner
    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Not Authorized");
        _;
    }

    function setOwner(address payable newOwner) external onlyOwner {
        contractOwner = payable(newOwner);
    }

    // Constructor to set the name and symbol of the ERC-721 token
    constructor() ERC721("ReceiptNFT", "RPT") {
        contractOwner = msg.sender;
    }

    function setDefaultURIRoot(string calldata _newRoot) public onlyOwner  {
        defaultURIRoot = _newRoot; 
    }

    function addApprovedCaller(address _toApprove) external onlyOwner {
        require(_toApprove != address(0), "Cannot approve the zero address");
        
        uint256 length = approvedCallers.length; // Cache the length in memory
        for (uint256 i = 0; i < length; i++) {
            require(approvedCallers[i] != _toApprove, "Address is already approved");
        }

        approvedCallers.push(_toApprove);
    }


    function removeApprovedCaller(address _toRemove) external onlyOwner {
        for (uint256 i = 0; i < approvedCallers.length; i++) {
            if (approvedCallers[i] == _toRemove) {
                // Swap the element to be removed with the last element
                approvedCallers[i] = approvedCallers[approvedCallers.length - 1];
                // Remove the last element from the array
                approvedCallers.pop();
                return;
            }
        }
        revert("Address not found in approved callers.");
    }

    function getApprovedCallers() public view returns (address[] memory) {
        return approvedCallers; 
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setRoyalty(uint256 promotionID, uint256 basisPoints) external onlyApprovedCallers {
        require(basisPoints <=10000, "Invalid"); //royalty over 100%
        royaltyBasisPoints[promotionID] = basisPoints; 
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
        // Return the royalty receiver and amount (calculated based on sale price)
        uint256 promotionID = tokenContexts[tokenId].promotionID; 
        if(promotionID == 0) {
            return (address(0), 0);
        }
        receiver = promotionOwners[promotionID]; 
        royaltyAmount = (salePrice * royaltyBasisPoints[promotionID]) / 10000;
        return (receiver, royaltyAmount);
    }
    
    function mintReceipts(address to, uint256 promotionID, uint256 participantNumber, uint256 numTokens) external onlyApprovedCallers returns(uint256 ) {
        uint256 initialID = receiptIDs +1; 
        for (uint256 i = 0; i < numTokens; i++) {
            _mint(to, initialID + i);
            tokenContexts[initialID+i] = TokenContext({
                promotionID: promotionID,
                participantNumber: participantNumber+i
            });
        }
        receiptIDs += numTokens;  
        return initialID;
    }

    function incrementReceiptIDs(uint256 numOrders) external onlyApprovedCallers returns(uint256) {
        uint256 initialID = receiptIDs+1;
        receiptIDs += numOrders;
        return initialID; 
    }

    function setPromotionOwner(uint256 promotionID, address promotionOwner) external onlyApprovedCallers {
        promotionOwners[promotionID] = promotionOwner;                                                                                                                     
    }

    function modifyPromotionURI(uint256 promotionID, string calldata newURIRoot) external onlyApprovedCallers {
        customURIRoot[promotionID] = newURIRoot; 
    } 
    
    function tokenURI(uint256 tokenID) public view override returns (string memory) {
        // Fetch promotionID and participantNumber from the Promotion Manager
        uint256 promotionID = tokenContexts[tokenID].promotionID; 
        uint256 participantNumber = tokenContexts[tokenID].participantNumber; 

        // Check if the promotionID is valid
        if (promotionID == 0) {
            revert TokenDoesNotExist();
        }

        // Retrieve the custom URI root for the promotion
        string memory uriRoot = customURIRoot[promotionID];

        // If no custom URI is set, use the default URI
        if (bytes(uriRoot).length == 0) {
            //return string(abi.encodePacked(defaultURIRoot, "/", uint2str(tokenID), ".json"));
            return string(abi.encodePacked(defaultURIRoot, "/", uint2str(participantNumber), ".json")); 
        } else {
            // Construct the custom URI using participantNumber
            return string(abi.encodePacked(uriRoot, "/", uint2str(participantNumber), ".json"));
        }
    }

    // Convert uint256 to string
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        while (_i != 0) {
            bstr[--len] = bytes1(uint8(48 + (_i % 10)));
            _i /= 10;
        }
        return string(bstr);
    }
}
