// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// event OperatorApproved(address indexed owner, address indexed approvedOperator);
// event OperatorRemoved(address indexed owner, address indexed removedOperator);
// error NotCustomURI();
// error URIAlreadSet();

// import "../interfaces/IReceiptManager.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// abstract contract PromotionManager {
//     uint256 public commission = 200; // basis points (divided by 10,000)
//     address payable public bank;
//     address public owner;
//     address public receiptManagerAddress;
//     mapping(address => uint256) public earnedCommissions;
//     mapping(address => uint256) public  withdrawnCommissions;
//     mapping(address => mapping(address => bool)) public  approvedOperators;
//     mapping(address => address[]) public  arrayOfApprovedOperators;
//     mapping(address => uint256[]) public addressToPromotions;
//     mapping(uint256 => address) public unmintedReceiptsToOwners;
//     mapping(uint256 => uint256[]) public promotionIDToReceiptIDs;
//     mapping(uint256 => uint256) public receiptIDToPromotionID; 
//     IReceiptManager public receiptManager;

//     modifier onlyOwner() {
//         require(msg.sender == owner, "NotOwner");
//         _;
//     }

//     modifier onlyReceiptManager() {
//         require(msg.sender == receiptManagerAddress, "NotOwner");
//         _;
//     }

//     // function getReceiptInfo(uint256 receiptID) public view virtual returns(uint256 promotionID, uint256 participantNumber); 
//     function setPromotionURI(uint256 promotionID, string calldata newURIRoot) external virtual;
//     function setRoyalty(uint256 promotionID, uint256 royaltyBPs) external virtual;

//     function getPromotionReceipts(uint256 promotionID) public view returns (uint256[] memory) {
//         uint256[] memory receipts = promotionIDToReceiptIDs[promotionID];
//         return (receipts);
//     }

//     function getNumberOfParticipants(uint256 promotionID) public view returns (uint256) {
//         return promotionIDToReceiptIDs[promotionID].length;
//     }


//     function getPromotionsByOwner(address promotionOwner) public view returns (uint256[] memory) {
//         return addressToPromotions[promotionOwner];
//     }

//     function setBank(address payable newBank) external onlyOwner {
//         bank = payable(newBank);
//     }

//     function setOwner(address payable newOwner) external onlyOwner {
//         owner = payable(newOwner);
//     }

//     function setReceiptManager(
//         address _receiptManagerAddress
//     ) external onlyOwner {
//         receiptManagerAddress = _receiptManagerAddress;
//         receiptManager = IReceiptManager(_receiptManagerAddress);
//     }


//     function withdrawCommissions(address erc20Token) external onlyOwner {
//         IERC20(erc20Token).transfer(
//             bank,
//             earnedCommissions[erc20Token] - withdrawnCommissions[erc20Token]
//         );
//         withdrawnCommissions[erc20Token] = earnedCommissions[erc20Token];
//     }

//     function approveOperator(address approvedOperator) public {
//         require(approvedOperator != address(0), "Cannot approve zero address.");
//         require(
//             !approvedOperators[msg.sender][approvedOperator],
//             "Operator already approved."
//         );

//         approvedOperators[msg.sender][approvedOperator] = true;
//         arrayOfApprovedOperators[msg.sender].push(approvedOperator);

//         emit OperatorApproved(msg.sender, approvedOperator);
//     }

//     function removeOperator(address toRemove) public {
//         require(
//             approvedOperators[msg.sender][toRemove],
//             "Operator not approved."
//         );

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

//     function getApprovedOperators(
//         address masterAccount
//     ) external view returns (address[] memory) {
//         return arrayOfApprovedOperators[masterAccount];
//     }

//     function setCommission(uint256 newCommissionBPs) external onlyOwner {
//         require(newCommissionBPs <= 10000, "Inv");
//         commission = newCommissionBPs; 
//     }
// }
