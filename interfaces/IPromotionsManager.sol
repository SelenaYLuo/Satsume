pragma solidity ^0.8.24;

interface IPromotionsManager {
    function approveOperator(
        address approvedOperator,
        address parentAccount
    ) external;

    function removeOperator(address toRemove, address parentAccount) external;

    function approveAdministrator(
        address approvedAdministrator,
        bool addOperator
    ) external;

    function removeAdministrator(
        address toRemove,
        bool removeAsOperator
    ) external;

    function isApprovedOperator(
        address operator,
        address parentAccount
    ) external view returns (bool);

    function getReceiverAddress(
        address userAddress,
        address tokenAddress
    ) external view returns (address);

    function getAllApprovedPromotions()
        external
        view
        returns (address[] memory);
}
