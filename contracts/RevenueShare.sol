// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.17;

// contract RevenueSharingPullModel {
//     struct Allocation {
//         address recipient;
//         uint256 percentage; // Percentage in basis points (1% = 100)
//     }

//     // Mapping of users to their allocations
//     mapping(address => Allocation[]) public userAllocations;

//     // Mapping of recipient addresses to their pending balances
//     mapping(address => uint256) public pendingWithdrawals;

//     // Total allocation percentage per user
//     mapping(address => uint256) public totalPercentage;

//     // Lock to prevent changes once funds are allocated
//     mapping(address => bool) public isLocked;

//     // Event emitted when funds are allocated
//     event FundsAllocated(address indexed sender, uint256 amount);

//     // Event emitted when a withdrawal is made
//     event Withdrawal(address indexed recipient, uint256 amount);

//     // Modifier to ensure percentages are valid
//     modifier validPercentages(address user, Allocation[] memory allocations) {
//         uint256 total = 0;
//         for (uint256 i = 0; i < allocations.length; i++) {
//             total += allocations[i].percentage;
//         }
//         require(total <= 10000, "Total percentage exceeds 100%");
//         _;
//     }

//     // Modifier to ensure allocations are unlocked
//     modifier allocationsUnlocked(address user) {
//         require(!isLocked[user], "Allocations are locked");
//         _;
//     }

//     // Function to set or update allocations
//     function setAllocations(
//         Allocation[] calldata allocations
//     )
//         external
//         allocationsUnlocked(msg.sender)
//         validPercentages(msg.sender, allocations)
//     {
//         delete userAllocations[msg.sender]; // Reset previous allocations

//         uint256 total = 0;
//         for (uint256 i = 0; i < allocations.length; i++) {
//             require(
//                 allocations[i].recipient != address(0),
//                 "Invalid recipient"
//             );
//             require(
//                 allocations[i].percentage > 0,
//                 "Percentage must be greater than 0"
//             );
//             total += allocations[i].percentage;

//             userAllocations[msg.sender].push(allocations[i]);
//         }

//         totalPercentage[msg.sender] = total;
//     }

//     // Function to allocate funds to recipients
//     function allocateFunds() external payable {
//         require(msg.value > 0, "No funds sent");
//         Allocation[] memory allocations = userAllocations[msg.sender];
//         require(allocations.length > 0, "No allocations set");

//         for (uint256 i = 0; i < allocations.length; i++) {
//             uint256 amount = (msg.value * allocations[i].percentage) / 10000;
//             pendingWithdrawals[allocations[i].recipient] += amount;
//         }

//         // Lock allocations for the sender
//         isLocked[msg.sender] = true;

//         emit FundsAllocated(msg.sender, msg.value);
//     }

//     // Function for recipients to withdraw their funds
//     function withdraw() external {
//         uint256 amount = pendingWithdrawals[msg.sender];
//         require(amount > 0, "No funds to withdraw");

//         pendingWithdrawals[msg.sender] = 0; // Reset balance before transferring
//         payable(msg.sender).transfer(amount);

//         emit Withdrawal(msg.sender, amount);
//     }

//     // Function to unlock allocations if all pending withdrawals are cleared
//     function unlockAllocations() external {
//         require(isLocked[msg.sender], "Allocations are already unlocked");

//         Allocation[] memory allocations = userAllocations[msg.sender];
//         for (uint256 i = 0; i < allocations.length; i++) {
//             require(
//                 pendingWithdrawals[allocations[i].recipient] == 0,
//                 "Pending withdrawals exist"
//             );
//         }

//         isLocked[msg.sender] = false;
//     }

//     // View function to get allocations for a user
//     function getAllocations(
//         address user
//     ) external view returns (Allocation[] memory) {
//         return userAllocations[user];
//     }

//     // View function to get pending balance for a recipient
//     function getPendingWithdrawal(
//         address recipient
//     ) external view returns (uint256) {
//         return pendingWithdrawals[recipient];
//     }
// }
