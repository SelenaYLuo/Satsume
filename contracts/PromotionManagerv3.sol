// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// error Snowball_InsufficientFund();
// error Promotion_Expired();
// error NoFundsToDistribute();
// error InvalidConfig(); 
// error TransferFail();
// error NotApproved();
// error AlreadyDrawn();
// error IneligibleDrawing(); 
// event SnowballCreated(uint256 snowballId);

// import "hardhat/console.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
// import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
// import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// interface ISnowballWorkingCapital {
//     function Loans(uint256 _loanID) external view returns (
//         address owner,
//         address debtor,
//         uint256 remainingAmount,
//         uint256 redeemableAmount
//     );
//     function repayDebt(uint256 _loanID, uint256 repaymentAmount) external;
// }

// interface ILoanFactory {
//     function Loans(uint256) external view returns (uint256, uint256, uint256, address);
//     function burnToken(uint256 tokenID) external;
//     function UpdateLoanAmount(uint256 loanID, uint256 subtractAmount) external;
// }

// interface IReceiptManager {
//     function createSnowballReceipt(
//         address to,
//         uint256 tokenId,
//         uint256 promotionID,
//         uint256 effectivePricePaid
//     ) external; 

//     function createDrawingReceipt(
//         address to,
//         uint256 tokenId,
//         uint256 promotionID,
//         uint256 participantNumber
//     ) external;

//     function createSeedReceipt(
//         address to,
//         uint256 tokenId,
//         uint256 promotionID,
//         uint256 participantNumber
//     ) external;

//     function nameDrawingWinner(uint256 tokenId, uint256 winningAmount) external; 
// }

// contract PromotionManager is VRFConsumerBaseV2  {
//     // Type Declarations
//     struct Snowball {
//         uint256 maxSlots; 
//         uint256 duration;
//         uint256 startTime;
//         uint256 numParticipants;
//         uint256[] thresholds;
//         uint256[] cohortPrices; 
//         uint256 custodyBalance; 
//         address owner; 
//         bool returnedCustody; 
//     }

//     struct Drawing {
//         uint256 maxSlots;
//         uint256 duration;
//         uint256 startTime;
//         uint256 numParticipants; 
//         uint256 price;
//         uint256 cohortSize;
//         uint256 rebateAmount;
//         uint256 custodyBalance; 
//         uint256[] winners; 
//         address owner; 
//         bool returnedCustody;
//     }

//     struct Seed {
//         uint256 seeds;
//         uint256 maxSlots;
//         uint256 price;
//         uint256 startTime;
//         uint256 duration;
//         uint256 numParticipants;
//         uint256 sharedAmount;
//         uint256 custodyAmount;
//     }

//     struct VRFRequestContext {
//         uint256 drawingID;
//         uint256 cohort;
//         uint256 randomWord; 
//     }

//     enum PromotionType { Snowball, Drawing, Seed }

    
    

//     /* State Variables */
//     uint256 public promotionIDs = 1; 
//     uint256 public promotionReceiptIDs = 1;
//     uint256 public earnedCommissions;
//     uint256 public withdrawnCommissions; 
//     uint256 public constant MINIMUM_PRICE = 5 * 10 ** 6;
//     uint256 public constant MINIMUM_DURATION = 900; 
//     uint256 public commission = 200; // basis points (divided by 10,000)
//     address payable public bank;
//     address public owner; 
//     address public s_forwarderAddress; 
//     address public receiptManagerAddress; 
//     uint256[] public activeDrawingsByID;
//     uint256[] public activeSnowballsByID;
//     uint256[] public activeSeedsByID; 
//     mapping(uint256 => PromotionType) public promotionTypes;
//     mapping(uint256 => Snowball) public Snowballs;
//     mapping(uint256 => Drawing) public Drawings;
//     mapping(uint256 => Seed) public Seeds;

//     mapping (address => uint256[]) public addressToActiveSnowballs;
//     mapping (address => uint256[]) public addressToInactiveSnowballs;
//     mapping (address => uint256[]) public addressToActiveSeeds;
//     mapping (address => uint256[]) public addressToInactiveSeeds;
//     mapping(address => uint256[]) public addressToActiveDrawings;
//     mapping(address => uint256[]) public addressToInactiveDrawings;
//     mapping(address => uint256) public userTotalDebt; 
//     mapping(address => uint256[]) public userOutstandingLoans; 
//     mapping(uint256 => mapping(uint256 => uint256)) drawingParticipantsToReceipts; 
//     mapping(uint256=> mapping(uint256 => uint256)) drawingCohortsToVRFRequestID;
//     mapping(uint256 => VRFRequestContext) vrfRequestIDtoContext; 

//     /* State Variables */
//     VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    
//     uint16 private constant REQUEST_CONFIRMATIONS = 3;
//     uint32 private immutable i_callbackGasLimit;
//     uint64 private immutable i_subscriptionId;
//     uint256 private s_lastTimeStamp;
//     bytes32 private immutable i_gasLane;

    

//     IReceiptManager public receiptManager; 
//     ILoanFactory public loanFactory; 
//     IERC20 public usdcToken; // Declare the USDC token contract
    

//     constructor(address _usdcToken, address vrfCoordinatorV2, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinatorV2) {
//         owner = msg.sender; // Set the owner to the contract deployer
//         bank = payable(owner);
//         usdcToken = IERC20(_usdcToken); // Initialize the USDC token contract
//         i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
//         i_gasLane = gasLane; 
//         i_subscriptionId = subscriptionId;
//         i_callbackGasLimit = callbackGasLimit;
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

//     function setReceiptManager(address _receiptManagerAddress) external onlyOwner {
//         receiptManagerAddress = _receiptManagerAddress; 
//         receiptManager = IReceiptManager(_receiptManagerAddress); 
//     }

//     function setLoanFactory(address _loanFactoryAddress) external onlyOwner {
//         loanFactory = ILoanFactory(_loanFactoryAddress); 
//     }
//     function withdrawCommissions() external onlyOwner {
//         usdcToken.transfer(bank, earnedCommissions - withdrawnCommissions);
//         withdrawnCommissions = earnedCommissions; 
//     }

//     function getSnowball(uint256 snowballID) public view returns(Snowball memory) {
//         return Snowballs[snowballID]; 
//     }

//     function getDrawing(uint256 drawingID) public view returns(Drawing memory) {
//         return Drawings[drawingID]; 
//     }

//     function createDrawing(
//         uint256 _maxSlots,
//         uint256 _duration,
//         uint256 _price,
//         uint256 _cohortSize,
//         uint256 _rebateAmount
//     ) public returns (uint256) {
//         if (_maxSlots % _cohortSize != 0 ||_price-_rebateAmount < MINIMUM_PRICE || _duration < MINIMUM_DURATION || _maxSlots <= 1 || _cohortSize==1) {
//             revert InvalidConfig();
//         }

//         // Initialize a new snowball contract and store it in storage
//         Drawing storage drawing = Drawings[promotionIDs];
//         drawing.maxSlots = _maxSlots;
//         drawing.duration = _duration;
//         drawing.owner = payable(msg.sender);
//         drawing.startTime = block.timestamp;
//         drawing.price = _price;
//         drawing.cohortSize = _cohortSize;
//         drawing.rebateAmount = _rebateAmount; 

//         // Initialize the winners array with the appropriate length
//         uint256 numCohorts = _maxSlots / _cohortSize;
//         drawing.winners = new uint256[](numCohorts);


//         activeDrawingsByID.push(promotionIDs); 
//         promotionTypes[promotionIDs] = PromotionType.Drawing;
//         addressToActiveDrawings[msg.sender].push(promotionIDs);
//         promotionIDs += 1; 
//         return promotionIDs;
//     }

//     function joinDrawing(uint256 drawingID, uint256 numTickets) public {
//         Drawing storage drawing = Drawings[drawingID]; 
//         if (drawing.numParticipants + numTickets > drawing.maxSlots || drawing.duration + drawing.startTime < block.timestamp){
//             revert Promotion_Expired(); //not necessarily, maybe just too many tickets
//         }
//         //drawing.numParticipants +=numTickets; 
//         drawing.custodyBalance += (drawing.rebateAmount) * numTickets; 
//         uint256 toSeller = (drawing.price-drawing.rebateAmount)*numTickets; 
//         uint256 commissionAmount = calculateCommission(toSeller) ;
//         usdcToken.transferFrom(msg.sender, address(this), (drawing.rebateAmount) * numTickets + commissionAmount); //pay commissions and send custody
//         earnedCommissions += commissionAmount;
//         payOwner(drawing.owner, toSeller - commissionAmount, false); //pay seller

//         //Create DrawingReceipts    
//         for(uint256 i =0; i<numTickets; i++) {
//             receiptManager.createDrawingReceipt(msg.sender, promotionReceiptIDs + i, drawingID, drawing.numParticipants + 1 + i);
//             drawingParticipantsToReceipts[drawingID][drawing.numParticipants + 1 + i] = promotionReceiptIDs + i;
//         }
//         promotionReceiptIDs += numTickets;
//         drawing.numParticipants+= numTickets; 
//     }

//     function initiateDrawing(uint256 _drawingID, uint256 _cohort) public  {
//         console.log(1);
//         require(drawingEligibility(_drawingID, _cohort), "Ineligible");         
//         console.log(2);
//         console.log(5);
//         uint256 requestId = i_vrfCoordinator.requestRandomWords(
//             i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, 1
//         );
//         console.log(requestId);
//         VRFRequestContext storage context = vrfRequestIDtoContext[requestId];
//         context.drawingID = _drawingID;
//         context.cohort = _cohort; 
//         drawingCohortsToVRFRequestID[_drawingID][_cohort] = requestId; 
//     }

//     function drawingEligibility(uint256 drawingID, uint256 cohort) public view returns (bool) {
//         Drawing storage drawing = Drawings[drawingID];
//         bool eligibility = true; 
//         if(drawing.winners[cohort]!=0 || 
//         drawing.numParticipants < drawing.cohortSize*(1+cohort) ||
//         vrfRequestIDtoContext[drawingCohortsToVRFRequestID[drawingID][cohort]].drawingID == drawingID) {
//             eligibility=false; 
//         }
//         return eligibility; 
//     }

//     //Should be external? add override. can it calldata?
//     function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override{
//         console.log("ffrw");
//         VRFRequestContext storage context = vrfRequestIDtoContext[requestId];
//         Drawing storage drawing = Drawings[context.drawingID];

//         //Store random word
//         context.randomWord = randomWords[0]; 

//         //Identify the winner. Add one to randomWord as there is no 0th participantNumber
//         uint256 winner = (context.cohort*drawing.cohortSize) + 1 + (randomWords[0]%drawing.cohortSize);
//         drawing.winners[context.cohort] = winner; 
//         uint256 winningReceiptID = drawingParticipantsToReceipts[context.drawingID][winner];
//         uint256 winningAmount = drawing.rebateAmount*drawing.cohortSize;
//         receiptManager.nameDrawingWinner(winningReceiptID, winningAmount);
//         usdcToken.approve(receiptManagerAddress, usdcToken.allowance(address(this), receiptManagerAddress) + winningAmount);
//     }


//     function retrieveExcessDrawingCustody(uint256 drawingID) public {
//         Drawing storage drawing = Drawings[drawingID];
        
//         // Ensure that the drawing has either ended or reached max participants
//         bool isExpiredOrFull = block.timestamp > drawing.duration + drawing.startTime || drawing.maxSlots == drawing.numParticipants;
        
//         // Check if the custody has already been returned
//         require(isExpiredOrFull, "Drawing is not expired or full yet.");
//         require(!drawing.returnedCustody, "Custody has already been returned.");

//         // Calculate excess custody based on remaining participants after filling cohorts
//         uint256 excessCustody = (drawing.numParticipants % drawing.cohortSize) * drawing.rebateAmount;
        
//         // Reduce custody balance by the excess custody amount
//         drawing.custodyBalance -= excessCustody;
        
//         // Calculate and deduct commission
//         uint256 commissionAmount = calculateCommission(excessCustody);
//         earnedCommissions += commissionAmount;
        
//         // Pay the owner the remaining amount after deducting the commission
//         payOwner(drawing.owner, excessCustody - commissionAmount, true);
        
//         // Mark custody as returned
//         drawing.returnedCustody = true;
//     }


//     function getCohortIsDrawn(uint256 drawingID, uint256 cohort) public view returns(bool) {
//         Drawing memory drawing = Drawings[drawingID];
//         if(drawing.winners[cohort] != 0) {
//             return true;
//         }
//         else {
//             return false; 
//         }
//     }

//     function getDrawableCohorts(uint256 drawingID) public view returns (uint256[] memory) {
//         Drawing memory drawing = Drawings[drawingID];
//         uint256 numPossibleDrawings = drawing.numParticipants/drawing.cohortSize;
//         uint256 numDrawable;

//         for(uint256 i =0; i <numPossibleDrawings; i++) {
//             if(drawing.winners[i] ==0) {
//                 numDrawable += 1; 
//             }
//         }

//         uint256[] memory drawable = new uint256[](numDrawable);
//         uint256 index = 0; 

//         for(uint256 i =0; i <numPossibleDrawings; i++) {
//             if(drawing.winners[i] ==0) {
//                 drawable[index] = i;
//                 index += 1;  
//             }
//         }

//         return drawable; 
//     }

//     function getEmptyArray() public pure returns (uint256[] memory) {
//         // Return an empty array
//         uint256[] memory emptyArray;
//         return emptyArray;
//     }


//     function getCohortTokens(uint256 drawingID, uint256 cohort) public view returns (uint256[] memory) {
//         Drawing memory drawing = Drawings[drawingID];
//         uint256 totalParticipants = drawing.numParticipants;
//         uint256 cohortSize = drawing.cohortSize;

//         // Special handling for the 0th cohort
//         if (cohort == 0) {
//             // Ensure the cohort has participants and doesn't go out of bounds
//             uint256 numTokens = totalParticipants < cohortSize ? totalParticipants : cohortSize;

//             uint256[] memory tokens = new uint256[](numTokens);
//             uint256 index = 0;

//             for (uint256 i = 1; i <= numTokens; i++) {
//                 uint256 tokenId = drawingParticipantsToReceipts[drawingID][i];
//                 if (tokenId != 0) {
//                     tokens[index] = tokenId;
//                     index++;
//                 }
//             }

//             return tokens;
//         }

//         // For non-0th cohorts
//         uint256 startIndex = cohort * cohortSize + 1;
//         uint256 endIndex = (cohort + 1) * cohortSize;

//         // Check if the cohort exceeds the number of participants
//         if (totalParticipants < startIndex) {
//             return new uint256[](0) ;  // Return an empty array if cohort is out of bounds
//         }

//         // If the cohort is incomplete, adjust the endIndex
//         if (totalParticipants < endIndex) {
//             endIndex = totalParticipants;
//         }

//         uint256 numTokens = endIndex - startIndex + 1;
//         uint256[] memory tokens = new uint256[](numTokens);
//         uint256 index = 0;

//         // Loop through the calculated range and add valid tokens
//         for (uint256 i = startIndex; i <= endIndex; i++) {
//             uint256 tokenId = drawingParticipantsToReceipts[drawingID][i];
//             if (tokenId != 0) {
//                 tokens[index] = tokenId;
//                 index++;
//             }
//         }

//         return tokens;
//     }

//     function getDrawingWinners(uint256 drawingID) public view returns (uint256[] memory) {
//         Drawing memory drawing = Drawings[drawingID];
//         uint256 numWinners;

//         // Calculate the number of winners (the non-zero participant numbers)
//         for (uint256 i = 0; i < drawing.winners.length; i++) {
//             if (drawing.winners[i] != 0) {
//                 numWinners += 1;
//             }
//         }

//         // Initialize an array with the length of numWinners
//         uint256[] memory winners = new uint256[](numWinners);
//         uint256 index = 0;

//         // Populate the winners array with non-zero winners and translate to receiptIDs. 
//         for (uint256 i = 0; i < drawing.winners.length; i++) {
//             if (drawing.winners[i] != 0) {
//                 winners[index] = drawingParticipantsToReceipts[drawingID][drawing.winners[i]];
//                 index += 1;
//             }
//         }

//         return winners;
//     }

//     //can the arrays be calldata?
//     function createSnowball(
//         uint256 _maxSlots,
//         uint256 _duration,
//         uint256[] memory _cohortPrices,
//         uint256[] memory _thresholds
//     ) public returns(uint256) {
//         if (_cohortPrices.length -1 != _thresholds.length || _cohortPrices.length < 1 || _cohortPrices.length > 5 || 
//         _thresholds[0] <=1 || _thresholds[_thresholds.length - 1]> _maxSlots || _thresholds[0]> _maxSlots ||_duration < MINIMUM_DURATION ||
//         _cohortPrices[_cohortPrices.length-1] <MINIMUM_PRICE) {
//             revert InvalidConfig(); 
//         }
//         // Check that _cohortPrices is strictly decreasing and _thresholds is strictly increasing
//         if (_thresholds.length >1 ){
//             for (uint256 i = 0; i < _thresholds.length; i++) {
//                 if (_cohortPrices[i] <= _cohortPrices[i + 1]) {
//                     revert InvalidConfig();
//                 }
//                 if (i > 0 && _thresholds[i] <= _thresholds[i - 1]) {
//                     revert InvalidConfig();
//                 }
//             }
//         }

//         // Initialize a new snowball contract and store it in storage
//         Snowball storage snowball = Snowballs[promotionIDs];
//         promotionTypes[promotionIDs] = PromotionType.Snowball;
//         snowball.maxSlots = _maxSlots;
//         snowball.duration = _duration;
//         snowball.thresholds = _thresholds;
//         snowball.owner = payable(msg.sender);
//         snowball.startTime = block.timestamp;
//         snowball.numParticipants = 0;
//         snowball.custodyBalance = 0;
//         snowball.cohortPrices = _cohortPrices;

//         activeSnowballsByID.push(promotionIDs); 
//         addressToActiveSnowballs[msg.sender].push(promotionIDs);
//         promotionIDs += 1; 
//         return promotionIDs;
//     }


//     function getSnowballCurrentPrice(uint256 snowballID) public view returns (uint256) {
//         Snowball memory snowball = Snowballs[snowballID]; 
//         return getSnowballPrice(snowball.cohortPrices, snowball.thresholds, snowball.numParticipants); 

//     }

//     function getSnowballPrice(uint256[] memory cohortPrices, uint256[] memory thresholds, uint256 updatedParticipants) public pure returns(uint256) {
//         uint256 updatedPrice =cohortPrices[0]; //Set to price of first cohort
//         for (uint256 i = 0; i < thresholds.length; i++) {
//             if(updatedParticipants >= thresholds[i]) {
//                 updatedPrice = cohortPrices[i+1];
//             }
//             else{
//                 break;
//             } 
//         }
//         return updatedPrice; 
//     }


    

//     function joinSnowball(uint256 snowballID, uint256 numTickets) public {
//         Snowball memory snowball = Snowballs[snowballID];
        
//         // Check for expiration or slot limits
//         if (snowball.duration + snowball.startTime < block.timestamp || snowball.numParticipants + numTickets > snowball.maxSlots) {
//             console.log("Revert");
//             revert Promotion_Expired();
//         }
        
//         // Calculate prices and custody amount
//         console.log("gp");
//         uint256 newPrice = getSnowballPrice(snowball.cohortPrices, snowball.thresholds, snowball.numParticipants + numTickets);
//         uint256 minPrice = snowball.cohortPrices[snowball.cohortPrices.length - 1];
//         uint256 custodyAmount = newPrice - minPrice;

//         console.log(newPrice);

//         // Update custody balance if needed
//         if (custodyAmount != 0) {
//             Snowballs[snowballID].custodyBalance += custodyAmount * numTickets;
//         }

//         // Calculate and transfer commission
//         console.log("commissions");
//         uint256 commissionAmount = calculateCommission(numTickets * minPrice);
//         usdcToken.transferFrom(msg.sender, address(this), commissionAmount + custodyAmount * numTickets);
//         usdcToken.approve(receiptManagerAddress, usdcToken.allowance(address(this), receiptManagerAddress) + custodyAmount * numTickets);

//         console.log(commissionAmount);

//         earnedCommissions += commissionAmount;
//         payOwner(snowball.owner, numTickets * minPrice - commissionAmount, false);
//         Snowballs[snowballID].numParticipants += numTickets;

//         console.log(Snowballs[snowballID].numParticipants);
//         for(uint256 i=0; i <numTickets; i++) {
//             receiptManager.createSnowballReceipt(msg.sender, promotionReceiptIDs+i, snowballID, newPrice);
//         }
        
//         promotionReceiptIDs += numTickets;
//     }


    
//     function retrieveExcessSnowballCustody(uint256 snowballID) public {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         uint256 excessCustody = calculateExcessSnowballCustody(snowballID);
//         //Check that the snowball has ended
//         require((block.timestamp > snowball.duration + snowball.startTime || snowball.maxSlots == snowball.numParticipants) && !snowball.returnedCustody, "active snowball");

//         //Return excess if the snowball has ended
//         uint256 commissionAmount = calculateCommission(excessCustody); //Commission is on all proceeds to sellers. 
//         earnedCommissions +=commissionAmount;
//         payOwner(snowball.owner, excessCustody-commissionAmount, true);
//         snowball.custodyBalance -=excessCustody; 
//         snowball.returnedCustody = true; 
//     }
    

//     function calculateExcessSnowballCustody(uint snowballID) public view returns(uint256) {
//         uint256 currentPrice = getSnowballCurrentPrice(snowballID );
//         uint256 excessCustody = (currentPrice-Snowballs[snowballID].cohortPrices[Snowballs[snowballID].cohortPrices.length-1]) * Snowballs[snowballID].numParticipants;
//         return  excessCustody;
//     }

//     //Should be private?
//     function payOwner(address snowballOwner,  uint256 amount, bool fromCustody) private {
//         if (fromCustody) {
//             usdcToken.transfer(snowballOwner, amount); 
//         }
//         else {
//             usdcToken.transferFrom(msg.sender, snowballOwner, amount); 
//         }
//     }
    


//     //Calculates the commissions given the non-custody amount
//     function calculateCommission(uint256 totalAmount) internal view returns (uint256) { //should be internal
//         uint256 commissionAmount = totalAmount *commission/10000; 
//         return (commissionAmount);
//     }


//     function reduceDrawingCustodyBalance(uint256 drawingID, uint256 reductionAmount) onlyReceiptManager external {
//         Drawings[drawingID].custodyBalance -= reductionAmount; 
//     }
//     function reduceSnowballCustodyBalance(uint256 snowballID, uint256 reductionAmount) onlyReceiptManager external {
//         Snowballs[snowballID].custodyBalance -= reductionAmount;
//     }
//     function isOwner(uint256 promotionID, address possibleOwner) public view returns(bool) {
//         PromotionType promoType = promotionTypes[promotionID];
//         if (promoType == PromotionType.Snowball) {
//             bool isOwner = (Snowballs[promotionID].owner == possibleOwner);
//             return isOwner;
//         }
//         else  {
//             bool isOwner = (Drawings[promotionID].owner == possibleOwner);
//             return isOwner;
//         }
//     }

    

//     function getActiveSnowballsByOwner(address user) public view returns (uint256[] memory) {
//         return addressToActiveSnowballs[user];
//     }

//     function createSeed(uint256 _maxSlots, uint256 _price, uint256 _cohortSize, uint256 _rebateAmount, uint256 _duration) public {
//         // Initialize a new snowball contract and store it in storage
//         Seed storage seed = Seeds[promotionIDs];
//         promotionTypes[promotionIDs] = PromotionType.Seed;
//         seed.maxSlots = _maxSlots;
//         seed.duration = _duration;
//         seed.owner = payable(msg.sender);
//         seed.startTime = block.timestamp;
//         seed.cohortSize = _cohortSize;
//         seed.rebateAmount = _rebateAmount;
//         seed.price = _price;

//         activeSeedsByID.push(promotionIDs); 
//         addressToActiveSeeds[msg.sender].push(promotionIDs);
//         promotionIDs += 1; 
//     }

//     function joinSeed(uint256 seedID, uint256 numTickets) public {
//         Seed storage seed = Seeds[promotionIDs];
//         require(seed.duration + seed.startTime >= block.timestamp && seed.maxSlots >= seed.numParticipants+numTickets, "Full"); 
        
//         uint256 increaseCustody;
//         uint256 increaseRedeemableAmount; 
//         for (uint256 i =0; i < numTickets; i++) {
//             if(numTickets + i +1 <= seed.cohortSize) {
//                 receiptManager.createSeedReceipt(msg.sender, promotionReceiptIDs, seedID, seed.numParticipants+i+1, true); 
//             } 
//             else {
//                 receiptManager.createSeedReceipt(msg.sender, promotionReceiptIDs, seedID, seed.numParticipants+i+1, false); 
//                 increaseCustody += seed.rebateAmount;
//                 increaseRedeemableAmount += seed.rebateAmount/seed.cohortSize; 
//             }
//         }
//         if(increaseCustody !=0 || increaseRedeemableAmount !=0) {
//             seed.custodyBalance += increaseCustody;
//             seed.redeemableAmount += increaseRedeemableAmount;
//         }
//     }

//     // function addUserDebt(address debtor, uint256 totalDebtAmount, uint256 loanID) external {
//     //     // if(msg.sender != WCProviderAddress) {
//     //     //     revert NotApproved(); 
//     //     // }
//     //     userOutstandingLoans[debtor].push(loanID); 
//     //     userTotalDebt[debtor] += totalDebtAmount; 
//     // }
// }
