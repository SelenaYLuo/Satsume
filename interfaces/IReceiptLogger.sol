pragma solidity ^0.8.24;

interface IReceiptLogger {
    function createSnowballReceipts(
        address to,
        uint256 promotionID,
        uint256 startParticipantNumber,
        uint256 effectivePricePaid,
        address erc20TokenAddress,
        uint256 numTickets,
        uint256 receiptTotalSupply
    ) external;

    function createDrawingReceipts(
        address to,
        uint256 promotionID,
        uint256 startParticipantNumber,
        address erc20TokenAddress,
        uint256 numTickets,
        uint256 receiptTotalSupply
    ) external;

    function createSeedReceipts(
        address to,
        uint256 promotionID,
        uint256 startParticipantNumber,
        address erc20TokenAddress,
        uint256 numSeeded,
        uint256 numNotSeeded,
        uint256 receiptTotalSupply
    ) external;

    function getTokenIDsInRange(
        uint256 promotionID,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (uint256[] memory);

    function rebateDrawingReceipts(
        uint256[] memory tokenIds,
        uint256 rebateAmount
    ) external;
}
