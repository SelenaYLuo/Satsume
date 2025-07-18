// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error NotCustomURI();
// error URIAlreadSet();

// import "../interfaces/IReceiptManager.sol";
// import "../interfaces/IPromotionsManager.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// abstract contract PromotionManager {
//     uint256 public commission = 200; // basis points (divided by 10,000)
//     address public contractOwner;
//     address public receiptManagerAddress;
//     address public promotionsManagerAddress;
//     mapping(address => uint256) public earnedCommissions;
//     mapping(address => uint256) public withdrawnCommissions;
//     mapping(address => mapping(address => bool)) public approvedOperators;
//     mapping(address => address[]) public arrayOfApprovedOperators;
//     mapping(address => uint256[]) public addressToPromotions;
//     mapping(uint256 => address) public unmintedReceiptsToOwners;
//     mapping(uint256 => uint256[]) public promotionIDToReceiptIDs;
//     mapping(uint256 => uint256) public receiptIDToPromotionID;
//     IReceiptManager public receiptManager;
//     IPromotionsManager public promotionsManager;

//     modifier onlyOwner() {
//         require(msg.sender == contractOwner, "NotOwner");
//         _;
//     }

//     modifier onlyReceiptManager() {
//         require(msg.sender == receiptManagerAddress, "NotOwner");
//         _;
//     }

//     modifier onlyApprovedOperators(address parentAccount) {
//         require(
//             promotionsManager.isApprovedOperator(msg.sender, parentAccount),
//             "Not Approved"
//         );
//         _;
//     }

//     // function getReceiptInfo(uint256 receiptID) public view virtual returns(uint256 promotionID, uint256 participantNumber);
//     function setPromotionURI(
//         uint256 promotionID,
//         string calldata newURIRoot
//     ) external virtual;

//     function setRoyalty(
//         uint256 promotionID,
//         uint256 royaltyBPs
//     ) external virtual;

//     function getPromotionReceipts(
//         uint256 promotionID
//     ) public view returns (uint256[] memory) {
//         uint256[] memory receipts = promotionIDToReceiptIDs[promotionID];
//         return (receipts);
//     }

//     function getNumberOfParticipants(
//         uint256 promotionID
//     ) public view returns (uint256) {
//         return promotionIDToReceiptIDs[promotionID].length;
//     }

//     function getPromotionsByOwner(
//         address promotionOwner
//     ) public view returns (uint256[] memory) {
//         return addressToPromotions[promotionOwner];
//     }

//     function setOwner(address payable newOwner) external onlyOwner {
//         contractOwner = payable(newOwner);
//     }

//     function setReceiptManager(
//         address _receiptManagerAddress
//     ) external onlyOwner {
//         receiptManagerAddress = _receiptManagerAddress;
//         receiptManager = IReceiptManager(_receiptManagerAddress);
//     }

//     function setPromotionsManager(
//         address _promotionsManagerAddress
//     ) external onlyOwner {
//         promotionsManagerAddress = _promotionsManagerAddress;
//         promotionsManager = IPromotionsManager(_promotionsManagerAddress);
//     }

//     function withdrawCommissions(address erc20Token) external onlyOwner {
//         IERC20(erc20Token).transfer(
//             contractOwner,
//             earnedCommissions[erc20Token] - withdrawnCommissions[erc20Token]
//         );
//         withdrawnCommissions[erc20Token] = earnedCommissions[erc20Token];
//     }

//     function setCommission(uint256 newCommissionBPs) external onlyOwner {
//         require(newCommissionBPs <= 10000, "Inv");
//         commission = newCommissionBPs;
//     }
// }
