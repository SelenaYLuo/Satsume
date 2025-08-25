// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// event OperatorApproved(address indexed parentAccount, address indexed approvedOperator);
// event OperatorRemoved(address indexed parentAccount, address indexed removedOperator);
// event AdministratorApproved(address indexed parentAccount, address indexed approvedAdministrator);
// event AdministratorRemoved(address indexed parentAccount, address indexed removedAdministrator);
// error NotCustomURI();
// error URIAlreadSet();

// // Interface for Promotion Contracts
// interface IPromotion {
//     function joinPromotion(uint256 promotionID, uint256 quantity, uint256 orderID, address buyer) external;
// }

// contract PromotionsManager {
//     address public contractOwner;
//     mapping(address => mapping(address => bool)) public  approvedOperators;
//     mapping(address => address[]) public  arrayOfApprovedOperators;
//     mapping(address => mapping(address => bool)) public  approvedAdministrators;
//     mapping(address => address[]) public  arrayOfApprovedAdministrators;
//     mapping(address => mapping(address => address)) public receiverAccounts;   
//     uint256[] public initialPromotionIDs; //sorted list
//     address[] public approvedPromotions; 
    

//     modifier onlyOwner() {
//         require(msg.sender == contractOwner, "Not Owner");
//         _;
//     }

//     constructor() { 
//         contractOwner = msg.sender; // Set the owner to the contract deployer
//     }

//     function setOwner(address newOwner) public onlyOwner {
//         contractOwner = newOwner; 
//     }

//     function approvePromotions(uint256 _initialID, address _promotionAddress) public onlyOwner {
//         uint256[] storage initialIDs = initialPromotionIDs;
//         address[] storage promotions = approvedPromotions;
//         uint256 length = initialIDs.length;
        
//         // Check for duplicate ID
//         for (uint256 i = 0; i < length; ) {
//             if (initialIDs[i] == _initialID) {
//                 revert("Duplicate promotion ID");
//             }
//             unchecked { ++i; }
//         }
        
//         // Find insertion position (maintain ascending order)
//         uint256 insertIndex = length;
//         for (uint256 i = 0; i < length; ) {
//             if (initialIDs[i] > _initialID) {
//                 insertIndex = i;
//                 break;
//             }
//             unchecked { ++i; }
//         }

//         // Expand arrays with dummy values
//         initialIDs.push(0);
//         promotions.push(address(0));

//         // Shift elements after insertion point
//         for (uint256 i = length; i > insertIndex; ) {
//             unchecked {
//                 initialIDs[i] = initialIDs[i - 1];
//                 promotions[i] = promotions[i - 1];
//                 --i;
//             }
//         }

//         // Insert new values
//         initialIDs[insertIndex] = _initialID;
//         promotions[insertIndex] = _promotionAddress;
//     }

//     function joinPromotions(uint256[] calldata promotionIDs, uint256[] calldata numOrders, uint256 orderID) public {
//         require(promotionIDs.length == numOrders.length, "Array length mismatch");
//         require(initialPromotionIDs.length > 0, "No promotions available");
        
//         // Cache arrays in memory for gas efficiency
//         uint256[] memory initialIDs = initialPromotionIDs;
//         address[] memory promotions = approvedPromotions;
//         uint256 promotionsLength = initialIDs.length;

//         for (uint256 i = 0; i < promotionIDs.length; ) {
//             uint256 promotionID = promotionIDs[i];
//             uint256 quantity = numOrders[i];
            
//             // Revert if ID is smaller than the first initial promotion ID
//             if (promotionID < initialIDs[0]) {
//                 revert("Invalid promotion ID");
//             }

//             // Start from the last promotion and work backwards
//             uint256 index = promotionsLength - 1;
            
//             // Find the largest initial ID <= promotionID
//             while (index > 0 && initialIDs[index] > promotionID) {
//                 unchecked { index--; }
//             }

//             address promotionContract = promotions[index];
//             IPromotion(promotionContract).joinPromotion(promotionID, quantity, orderID, msg.sender);
            
//             unchecked { i++; }
//         }
//     }

//     function approveOperator(address approvedOperator, address parentAccount) public {
//         require(approvedOperator != address(0), "Cannot approve zero address.");
//         require(
//             !approvedOperators[parentAccount][approvedOperator],
//             "Operator already approved."
//         );
//         require(parentAccount ==  msg.sender || approvedAdministrators[parentAccount][msg.sender], "Not approved administrator");

//         approvedOperators[parentAccount][approvedOperator] = true;
//         arrayOfApprovedOperators[parentAccount].push(approvedOperator);

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
//             "Admin already approved."
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
//             "Administrator not approved."
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
//         return (approvedOperators[parentAccount][operator] || operator == parentAccount); 
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