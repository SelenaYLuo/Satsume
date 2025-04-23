pragma solidity ^0.8.24;

interface IPromotionManager {
    function getReceiptInfo(
        uint256 receiptID
    ) external view returns (uint256 promotionID, uint256 participantNumber);
}
