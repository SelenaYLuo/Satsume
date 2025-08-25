pragma solidity ^0.8.24;

interface IProxy {
    function getAllApprovedPromotions()
        external
        view
        returns (address[] memory);
}
