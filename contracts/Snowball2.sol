// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error Snowball_InsufficientFund();
// error Snowball_Expired();
// error noFundsToDistribute();

// import "hardhat/console.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// //import "@chainlink/contracts/src/v0.8/vrf/interfaces/KeeperCompatibleInterface.sol";
// import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

// contract Snowball2 is AutomationCompatibleInterface {
//     //Type Declarations
//     enum State {
//         OPEN,
//         CLOSED
//     }

//     struct snowballContract {
//         uint256 id;
//         uint256 maxSlots;
//         uint256 price;
//         uint256 duration;
//         uint256[] payouts;
//         uint256[] thresholds;
//         address payable owner;
//         uint256 startTime;
//         State snowballState;
//         address payable[] participants;
//         uint256 targetThresholdIndex;
//         uint256 balance;
//         bool maxDiscount;
//     }

//     snowballContract[] public allSnowballContracts;
//     snowballContract[] public activeSnowballContracts;
//     mapping(uint256 => snowballContract) public s_idToSnowball;
//     uint256 public constant MINIMUM_PRICE = 5 * 10 ** 18;
//     uint256 public constant SNOWBALL_COST = 5 * 10 ** 18;

//     function createSnowball(
//         uint256 _maxSlots,
//         uint256 _price,
//         uint256 _duration,
//         uint256[] memory _payouts,
//         uint256[] memory _thresholds
//     ) public payable {
//         uint256[] memory pay = new uint256[](_payouts.length);
//         uint256[] memory thresh = new uint256[](_thresholds.length);
//         for (uint256 i = 0; i < _payouts.length; i++) {
//             pay[i] = _payouts[i];
//         }
//         for (uint256 i = 0; i < _thresholds.length; i++) {
//             thresh[i] = _thresholds[i];
//         }
//         bool maxedDiscounts;
//         //Check that there are discount thresholds.
//         if (_thresholds.length == 0) {
//             maxedDiscounts = true;
//         } else {
//             maxedDiscounts = false;
//         }

//         snowballContract memory newSnowball = snowballContract(
//             allSnowballContracts.length, //this is the id
//             _maxSlots,
//             _price,
//             _duration,
//             pay,
//             thresh,
//             payable(msg.sender),
//             block.timestamp,
//             State.OPEN,
//             new address payable[](0),
//             0,
//             0,
//             maxedDiscounts
//         );

//         s_idToSnowball[allSnowballContracts.length] = newSnowball;
//         allSnowballContracts.push(newSnowball);
//         activeSnowballContracts.push(newSnowball);
//     }

//     function joinContract(uint256 id) public payable {
//         snowballContract storage snowball = s_idToSnowball[id];

//         //Check if the sent value is sufficient
//         if (msg.value < snowball.price) {
//             revert Snowball_InsufficientFund();
//         }
//         //check if the contract is still valid
//         if (snowball.snowballState != State.OPEN) {
//             revert Snowball_Expired();
//         }

//         snowball.balance += msg.value;
//         snowball.participants.push(payable(msg.sender));
//         uint256 numParticipants = snowball.participants.length;

//         //Check if we have reached the maximum number of participants and close the contract if so
//         if (numParticipants == snowball.maxSlots) {
//             snowball.snowballState = State.CLOSED;
//             if (
//                 numParticipants ==
//                 snowball.thresholds[snowball.targetThresholdIndex] &&
//                 snowball.targetThresholdIndex == snowball.thresholds.length - 1
//             ) {
//                 snowball.maxDiscount = true;
//             }
//         }
//         //Check if we have previously passed into the last discount slot
//         else if (snowball.maxDiscount == true) {
//             //do nothing
//         }
//         //Check if we have reached a new index that is not the last index
//         else if (
//             numParticipants ==
//             snowball.thresholds[snowball.targetThresholdIndex] &&
//             snowball.targetThresholdIndex < snowball.thresholds.length - 1
//         ) {
//             snowball.price =
//                 snowball.price -
//                 snowball.payouts[snowball.targetThresholdIndex]; //new discounted price
//             snowball.targetThresholdIndex += 1; //new index for discount/pricing thresholds
//         }
//         //check if we have reached the final index level
//         else if (
//             numParticipants ==
//             snowball.thresholds[snowball.targetThresholdIndex] &&
//             snowball.targetThresholdIndex == snowball.thresholds.length - 1
//         ) {
//             snowball.price =
//                 snowball.price -
//                 snowball.payouts[snowball.targetThresholdIndex]; //new discounted price
//             snowball.maxDiscount = true;
//         }
//     }

//     function payParticipants(uint256 id) public returns (bool) {
//         snowballContract storage snowball = s_idToSnowball[id];
//         uint256 numParticipants = snowball.participants.length;
//         uint256 balance = snowball.balance;

//         if (balance == 0) {
//             return false;
//         } else {
//             uint256[] memory thresholds = snowball.thresholds;
//             uint256[] memory payouts = snowball.payouts;
//             address payable[] memory participants = snowball.participants;

//             //if we never reached the first threshold, return all money to contract owner.
//             if (snowball.targetThresholdIndex == 0) {
//                 (bool success, ) = snowball.owner.call{value: balance}("");
//                 if (success) {
//                     snowball.balance = 0;
//                 }
//             } else {
//                 //we loop through each of the cohorts, starting from earliest participants and pay them the discounts
//                 uint256 lowerBound = 0;
//                 for (uint256 i = 0; i <= snowball.targetThresholdIndex; i++) {
//                     uint256 cohortPaymentAmount;
//                     if (snowball.maxDiscount) {
//                         cohortPaymentAmount = sumArray(
//                             payouts,
//                             i,
//                             snowball.targetThresholdIndex
//                         );
//                     } else {
//                         cohortPaymentAmount = sumArray(
//                             payouts,
//                             i,
//                             snowball.targetThresholdIndex - 1
//                         );
//                     }
//                     uint256 upperBound = Math.min(
//                         thresholds[i],
//                         numParticipants
//                     );
//                     for (uint256 j = lowerBound; j < upperBound; j++) {
//                         (bool success, ) = participants[j].call{
//                             value: cohortPaymentAmount
//                         }("");
//                         if (success) {
//                             balance -= cohortPaymentAmount;
//                         }
//                     }
//                     lowerBound = upperBound;
//                 }
//                 (bool success, ) = snowball.owner.call{value: balance}("");
//                 if (success) {
//                     snowball.balance = 0;
//                 }
//             }
//             snowball.snowballState = State.CLOSED;
//             return true;
//         }
//     }

//     function checkUpkeep(
//         bytes memory /*checkData*/
//     )
//         public
//         view
//         override
//         returns (bool upkeepNeeded, bytes memory performData)
//     {
//         upkeepNeeded = false;
//         uint256[] memory listOfUpkeeps;
//         uint256 indexCounter = 0;
//         for (uint256 i = 0; i < activeSnowballContracts.length; i++) {
//             snowballContract memory snowball = activeSnowballContracts[i];
//             if (
//                 snowball.snowballState == State.CLOSED ||
//                 block.timestamp - snowball.startTime > snowball.duration
//             ) {
//                 listOfUpkeeps[indexCounter] = snowball.id; //////////////////////////
//                 upkeepNeeded = true;
//                 indexCounter++;
//             }
//         }
//         performData = abi.encode(listOfUpkeeps);
//         return (upkeepNeeded, performData);

//         // bool isOpen = (RaffleState.OPEN == s_raffleState);
//         // bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
//         // bool hasPlayers = s_players.length > 0;
//         // bool hasBalance = address(this).balance > 0;
//         // upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
//     }

//     function performUpkeep(bytes calldata performData) external override {
//         uint256[] memory listOfUpkeeps = abi.decode(performData, (uint256[]));
//         for (uint256 i = 0; i < listOfUpkeeps.length; i++) {
//             snowballContract storage snowball = activeSnowballContracts[
//                 listOfUpkeeps[i]
//             ];
//             snowball.snowballState = State.CLOSED;
//             payParticipants(snowball.id);
//             RemoveArayItem(activeSnowballContracts, listOfUpkeeps[i]);
//         }
//     }

//     function sumArray(
//         uint256[] memory arr,
//         uint256 start,
//         uint256 end
//     ) public pure returns (uint256 result) {
//         for (uint256 i = start; i <= end; i++) {
//             result += arr[i]; ///change this in final production
//         }
//         return result;
//     }

//     function RemoveArayItem(
//         snowballContract[] storage array,
//         uint256 indexToRemove
//     ) internal returns (snowballContract[] memory) {
//         array[indexToRemove] = array[array.length - 1];
//         array.pop();
//         return array;
//     }

//     function testCreate(uint256[] memory a, uint256[] memory b) public {
//         uint256[] memory first = new uint256[](a.length);
//         uint256[] memory second = new uint256[](b.length);
//         for (uint256 i = 0; i < a.length; i++) {
//             //uint256 num = i* 10**18;
//             first[i] = a[i] * 10 ** 18;
//         }
//         for (uint256 i = 0; i < b.length; i++) {
//             second[i] = b[i];
//         }

//         // p[0] = 1;
//         // p[1] = 2;

//         // t[0] = 1;
//         // t[1] = 3;
//         createSnowball(10, 5 * 10 ** 18, 100, first, second);
//     }

//     function returnArray(uint256 index) public returns (address) {
//         allSnowballContracts[index].participants.push(
//             payable(0x1234567890123456789012345678901234567890)
//         );
//         return allSnowballContracts[index].participants[0];
//     }
// }
