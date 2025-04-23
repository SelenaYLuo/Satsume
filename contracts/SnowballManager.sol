// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error Promotion_Expired();
// error InvalidConfig(); 
// error NotApproved();
// error DoesNotExist();

// event SnowballCreated(address indexed owner, uint256 indexed snowballID, address indexed erc20Token, uint256 maxSlots, uint256 endTime, uint256[] thresholds, uint256[] cohortPrices);
// event SnowballCustodyRedeemed(uint256 indexed snowballID, uint256 redeemedAmount); 
// event SnowballCancelled(uint256 indexed snowballID, uint256 numberOfParticipants);
// event SnowballReceiptRedeemed(uint256 indexed tokenID, uint256 indexed snowballID, uint256 redeemedAmount); 
// event SnowballReceiptsMinted(address indexed joiner, uint256 indexed snowballID, uint256 firstParticipantNumber, uint256 firstTokenID, uint256 pricePaid, uint256 numTickets);
// event OperatorApproved(address indexed owner, address indexed approvedOperator);
// event OperatorRemoved(address indexed owner, address indexed removedOperator);


// import "hardhat/console.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../interfaces/IReceiptManager.sol";

// contract SnowballManager {
//     struct Snowball {
//         uint256 maxSlots; 
//         uint256 endTime;
//         uint256 numParticipants;
//         uint256[] thresholds;
//         uint256[] cohortPrices; 
//         uint256 custodyBalance; 
//         address owner; 
//         bool returnedCustody; 
//         address erc20Token; 
//     }

//     struct SnowballReceipt {
//         uint256 snowballID;
//         uint256 effectivePricePaid;
//     }

//     uint256 public snowballIDs = 1; 
//     uint256 public constant MINIMUM_DURATION = 900; 
//     uint256 public commission = 200; // basis points (divided by 10,000)
//     address payable public bank;
//     address public owner; 
//     address public receiptManagerAddress; 

//     mapping(uint256 => SnowballReceipt) public SnowballReceipts;
//     mapping(uint256 => Snowball) public Snowballs;
//     mapping(address => mapping(address => bool)) approvedOperators;
//     mapping(address => uint256) earnedCommissions;
//     mapping(address => uint256) withdrawnCommissions; 

//     IReceiptManager public receiptManager; 

//     constructor() { 
//         owner = msg.sender; // Set the owner to the contract deployer
//         bank = payable(owner);
//     }

//     modifier onlyOwner() {
//         require(msg.sender == owner, "NotOwner");
//         _;
//     }

//     modifier onlyReceiptManager() {
//         require(msg.sender == receiptManagerAddress, "NotOwner");
//         _;
//     }

//     function setBank(address payable newBank) external onlyOwner {
//         bank = payable(newBank);
//     }

//     function setOwner(address payable newOwner) external onlyOwner {
//         owner = payable(newOwner);
//     }

//     function setReceiptManager(address _receiptManagerAddress) external onlyOwner {
//         receiptManagerAddress = _receiptManagerAddress; 
//         receiptManager = IReceiptManager(_receiptManagerAddress); 
//     }

//     //Approve main ERC20 stablecoins. Can later approve new coins. 
//     function approveERC20Token(address _erc20TokenAddress) external {
//         IERC20(_erc20TokenAddress).approve(receiptManagerAddress, type(uint256).max);
//     }
 
//     function withdrawCommissions(address erc20Token) external onlyOwner {
//         IERC20(erc20Token).transfer(bank, earnedCommissions[erc20Token] - withdrawnCommissions[erc20Token]);
//         withdrawnCommissions[erc20Token] = earnedCommissions[erc20Token]; 
//     }

//     function approveOperator(address approvedOperator) public {
//         require(approvedOperator != address(0), "Cannot approve zero address.");
//         approvedOperators[msg.sender][approvedOperator] = true; 
//         emit OperatorApproved(msg.sender, approvedOperator);
//     }

//     function removeOperator(address toRemove) public {
//         approvedOperators[msg.sender][toRemove] = false;
//         emit OperatorRemoved(msg.sender, toRemove);
//     }

//     function createSnowball(
//         uint256 _maxSlots,
//         uint256 _duration,
//         uint256[] calldata _cohortPrices,
//         uint256[] calldata _thresholds,
//         address _owner,
//         address _erc20Token
//     ) public {
//         if (_cohortPrices.length -1 != _thresholds.length || 
//             _cohortPrices.length < 2 || 
//             _cohortPrices.length > 5 || 
//             _thresholds[0] <=1 || 
//             _thresholds[_thresholds.length - 1]> _maxSlots || 
//             _duration < MINIMUM_DURATION ) {
//             revert InvalidConfig(); 
//         }

//         // Check that _cohortPrices is strictly decreasing, and all values are nonzero
//         for (uint256 i = 0; i < _cohortPrices.length; i++) {
//             if (_cohortPrices[i] == 0) {
//                 revert InvalidConfig(); // Reject zero values in _cohortPrices
//             }
//             if (i != 0) {
//                 if (_cohortPrices[i] >= _cohortPrices[i - 1]) {
//                     revert InvalidConfig(); // Ensure strictly decreasing order
//                 }
//             }
//         }

//         // Check that _thresholds is strictly increasing
//         if (_thresholds.length > 1) {
//             for (uint256 i = 1; i < _thresholds.length; i++) {
//                 if (_thresholds[i] <= _thresholds[i - 1]) {
//                     revert InvalidConfig(); // Ensure strictly increasing order
//                 }
//             }
//         }
//         if (msg.sender != _owner && !approvedOperators[_owner][msg.sender]) {
//             revert NotApproved(); 
//         }

//         // Initialize a new snowball contract and store it in storage
//         Snowball storage snowball = Snowballs[snowballIDs];
//         snowball.maxSlots = _maxSlots;
//         snowball.thresholds = _thresholds;
//         snowball.owner = payable(_owner);
//         snowball.endTime = block.timestamp +_duration;
//         snowball.cohortPrices = _cohortPrices;
//         snowball.erc20Token = _erc20Token;

//         emit SnowballCreated(_owner, snowballIDs, _erc20Token, _maxSlots, _duration + block.timestamp, _thresholds, _cohortPrices);
//         snowballIDs += 1; 
//     }

//     function joinSnowball(uint256 snowballID, uint256 numOrders) public {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         uint256 numParticipants = snowball.numParticipants; 
//         address erc20Token = snowball.erc20Token; 

//         // Check for expiration or slot limits
//         require(block.timestamp < snowball.endTime, "Expired");
//         require(numParticipants + numOrders <= snowball.maxSlots, "Full");

//         uint256 newPrice = snowball.cohortPrices[0]; //Set to price of first cohort
//         for(uint256 i =0; i < snowball.thresholds.length; i++) {
//             if(numParticipants + numOrders >= snowball.thresholds[i]) {
//                 newPrice = snowball.cohortPrices[i+1];
//             }
//             else {
//                 break;
//             }
//         }

//         uint256 minPrice = snowball.cohortPrices[snowball.cohortPrices.length - 1];
//         uint256 totalCustodyAmount = (newPrice - minPrice) * numOrders;

//         // Update custody balance if needed
//         if (totalCustodyAmount != 0) {
//             snowball.custodyBalance += totalCustodyAmount;
//         }

//         // Calculate commission
//         uint256 commissionAmount = (numOrders * minPrice)*commission/10000;

//         // Perform a single transfer for efficiency
//         IERC20(erc20Token).transferFrom(msg.sender, address(this), newPrice*numOrders);

//         // Update commissions and pay the owner
//         earnedCommissions[erc20Token] += commissionAmount;
//         uint256 ownerPayment = numOrders * minPrice - commissionAmount;
//         IERC20(erc20Token).transfer(snowball.owner, ownerPayment);

//          //Get total supply of receiptIDs
//         uint256 totalSupply = receiptManager.totalSupply();

//         //Mint NFT-Receipts
//         uint256 initialTokenID = receiptManager.mintReceipts(msg.sender, snowballID, 0, numOrders); //0 to represent snowball, 1 for drawing, 2 for seed 

//         //Log the receipt details
//         for (uint256 i=0; i<initialTokenID; i++) {
//             SnowballReceipt storage snowballReceipt = SnowballReceipts[initialTokenID + i];
//             snowballReceipt.snowballID = snowballID;
//             snowballReceipt.effectivePricePaid = newPrice; 
//         }

//         emit SnowballReceiptsMinted(
//             msg.sender, 
//             snowballID, 
//             numParticipants+1, 
//             initialTokenID, 
//             newPrice, 
//             numOrders
//         );

//         // Update participants count
//         snowball.numParticipants += numOrders;
//     }

//     function redeemSnowballReceipts(uint256[] calldata tokenIDs) external {
//         uint256 redeemableAmount; 
//         address erc20Token = Snowballs[SnowballReceipts[tokenIDs[0]].snowballID].erc20Token; //erc20 address of the first token
//         for(uint256 i =0; i < tokenIDs.length; i++) {
//             SnowballReceipt memory snowballReceipt = SnowballReceipts[tokenIDs[i]];
//             Snowball storage snowball = Snowballs[snowballReceipt.snowballID];
//             require(erc20Token == snowball.erc20Token, "Invalid"); 
//             require((receiptManager.ownerOf(tokenIDs[i]) == msg.sender), "Not owned");
//             uint256 snowballPrice = getSnowballPrice(snowballReceipt.snowballID);
//             if (snowballReceipt.effectivePricePaid > snowballPrice) {
//                 redeemableAmount += (snowballReceipt.effectivePricePaid - snowballPrice);
//                 SnowballReceipts[tokenIDs[i]].effectivePricePaid = snowballPrice;
//                 reduceSnowballCustody(snowballReceipt.snowballID, snowballReceipt.effectivePricePaid - snowballPrice);
//             }
//             emit SnowballReceiptRedeemed(tokenIDs[i], snowballReceipt.snowballID, redeemableAmount);
//         }
//         if(redeemableAmount !=0) {
//             IERC20(erc20Token).transfer(
//                 msg.sender,
//                 redeemableAmount
//             );
//         }
//     }

//     function getSnowballPrice(uint256 snowballID) public view returns(uint256) {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         if(snowball.maxSlots == snowball.numParticipants) {
//             /*
//             In this case, the price must be that of the last cohort. This edge 
//             check is needed as cancelling a Snowball early sets maxSlots to numParticipants, 
//             thus looping through thresholds will not produce the intended result of 
//             returning the lowest possible price. 
//             */
//             return snowball.cohortPrices[snowball.cohortPrices.length-1]; 
//         }
//         uint256 updatedPrice = snowball.cohortPrices[0]; //Set to price of first cohort
//         uint256 thresholdsLength = snowball.thresholds.length;
//         for (uint256 i = 0; i < thresholdsLength; i++) {
//             if(snowball.numParticipants >= snowball.thresholds[i]) {
//                 updatedPrice = snowball.cohortPrices[i+1];
//             }
//             else{
//                 break;
//             } 
//         }
//         return updatedPrice; 
//     }

//     function reduceSnowballCustody(uint256 snowballID, uint256 reductionAmount) internal {
//         Snowball storage snowball = Snowballs[snowballID];
//         snowball.custodyBalance -= reductionAmount; 
//     }

//     function retrieveExcessSnowballCustody(uint256 snowballID) public {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         //Check that the snowball has ended
//         require((block.timestamp > snowball.endTime || snowball.maxSlots == snowball.numParticipants) && !snowball.returnedCustody, "Ineligible");
//         // Caculate excess custody
//         uint256 excessCustody = calculateExcessSnowballCustody(snowballID);        
//         //Return excess if the snowball has ended
//         uint256 commissionAmount = excessCustody*commission/10000; //Commission is on all proceeds to sellers. 
//         earnedCommissions[snowball.erc20Token] += commissionAmount;
//         IERC20(snowball.erc20Token).transfer(snowball.owner, excessCustody-commissionAmount); 
//         snowball.custodyBalance -=excessCustody; 
//         snowball.returnedCustody = true; 
//         emit SnowballCustodyRedeemed(snowballID, excessCustody);
//     }
    

//     function calculateExcessSnowballCustody(uint snowballID) public view returns(uint256) {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         uint256 currentPrice = getSnowballPrice(snowballID);
//         uint256 excessCustody = (currentPrice-snowball.cohortPrices[snowball.cohortPrices.length-1]) * snowball.numParticipants;
//         return  excessCustody;
//     }

// }