pragma solidity ^0.8.24;

interface IReceiptManager {
    function setRoyalty(uint256 promotionID, uint256 basisPoints) external;

    function setPromotionOwner(
        uint256 promotionID,
        address promotionOwner
    ) external;

    function mintReceipts(
        address to,
        uint256 promotionID,
        uint256 participantNumber,
        uint256 numTokens
    ) external returns (uint256);

    function incrementReceiptIDs(uint256 numOrders) external returns (uint256);

    function modifyPromotionURI(
        uint256 promotionID,
        string calldata newURIRoot
    ) external;

    function ownerOf(uint256 tokenId) external view returns (address);

    function customURIRoot(uint256 key) external view returns (string memory);
}
