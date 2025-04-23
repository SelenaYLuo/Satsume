// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// event OperatorApproved(address indexed parentAccount, address indexed approvedOperator);
// event OperatorRemoved(address indexed parentAccount, address indexed removedOperator);
// event AdministratorApproved(address indexed parentAccount, address indexed approvedAdministrator);
// event AdministratorRemoved(address indexed parentAccount, address indexed removedAdministrator);
// error NotCustomURI();
// error URIAlreadSet();


// contract PromotionsManager {
//     mapping(address => mapping(address => bool)) public  approvedOperators;
//     mapping(address => address[]) public  arrayOfApprovedOperators;
//     mapping(address => mapping(address => bool)) public  approvedAdministrators;
//     mapping(address => address[]) public  arrayOfApprovedAdministrators;
//     mapping(address => mapping(address => address)) public receiverAccounts;   

//     function approveOperator(address approvedOperator, address parentAccount) public {
//         require(approvedOperator != address(0), "Cannot approve zero address.");
//         require(
//             !approvedOperators[parentAccount][approvedOperator],
//             "Operator already approved."
//         );
//         require(parentAccount ==  msg.sender || approvedAdministrators[parentAccount][msg.sender], "Not approved administrator");

//         approvedOperators[msg.sender][approvedOperator] = true;
//         arrayOfApprovedOperators[msg.sender].push(approvedOperator);

//         emit OperatorApproved(parentAccount, approvedOperator);
//     }

//     function removeOperator(address toRemove, address parentAccount) public {
//         require(
//             approvedOperators[parentAccount][toRemove],
//             "Operator not approved."
//         );
//         require(parentAccount ==  msg.sender || approvedAdministrators[parentAccount][msg.sender], "Not approved administrator");

//         approvedOperators[parentAccount][toRemove] = false;

//         // Remove the address from the array
//         address[] storage operators = arrayOfApprovedOperators[parentAccount];
//         for (uint256 i = 0; i < operators.length; i++) {
//             if (operators[i] == toRemove) {
//                 operators[i] = operators[operators.length - 1]; // Replace with the last element
//                 operators.pop(); // Remove the last element
//                 break;
//             }
//         }

//         emit OperatorRemoved(parentAccount, toRemove);
//     }

//     function approveAdministrator(address approvedAdministrator, bool addOperator) public {
//         require(approvedAdministrator != address(0), "Cannot approve zero address.");
//         require(
//             !approvedAdministrators[msg.sender][approvedAdministrator],
//             "Operator already approved."
//         );

//         approvedAdministrators[msg.sender][approvedAdministrator] = true;
//         arrayOfApprovedAdministrators[msg.sender].push(approvedAdministrator);

//         emit AdministratorApproved(msg.sender, approvedAdministrator);
//         if (addOperator) {
//             approveOperator(approvedAdministrator, msg.sender);
//         }
//     }

//     function removeAdministrator(address toRemove, bool removeAsOperator) public {
//         require(
//             approvedAdministrators[msg.sender][toRemove],
//             "Operator not approved."
//         );
//         approvedAdministrators[msg.sender][toRemove] = false;

//         // Remove the address from the array
//         address[] storage operators = arrayOfApprovedAdministrators[msg.sender];
//         for (uint256 i = 0; i < operators.length; i++) {
//             if (operators[i] == toRemove) {
//                 operators[i] = operators[operators.length - 1]; // Replace with the last element
//                 operators.pop(); // Remove the last element
//                 break;
//             }
//         }

//         emit AdministratorRemoved(msg.sender, toRemove);
//         if (removeAsOperator && approvedOperators[msg.sender][toRemove]) {
//             removeOperator(toRemove, msg.sender);
//         }
//     }

//     function isApprovedOperator(address operator, address parentAccount) public view returns(bool) {
//         return (approvedOperators[parentAccount][operator] ||operator == parentAccount); 
//     }

//     function getApprovedOperators(
//         address masterAccount
//     ) external view returns (address[] memory) {
//         return arrayOfApprovedOperators[masterAccount];
//     }

//     function getApprovedAdministrators(
//         address masterAccount
//     ) external view returns (address[] memory) {
//         return arrayOfApprovedAdministrators[masterAccount];
//     }

//     function updateReceiverAddress(address tokenAddress, address receiverAddress) public {
//         receiverAccounts[msg.sender][tokenAddress] = receiverAddress; 
//     }

//     function getReceiverAddress(address userAddress, address tokenAddress) public view returns (address) {
//         address receiver = receiverAccounts[userAddress][tokenAddress];
//         if (receiver == address(0)) {
//             return userAddress;
//         } else {
//             return receiver;
//         }
//     }
// }