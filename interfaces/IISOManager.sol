pragma solidity ^0.8.24;

interface IISOManager {
    function payStore(
        address store,
        uint256 toStore,
        uint256 commission,
        uint256 custodyAmount,
        address erc20Token,
        address payor
    ) external;
}
