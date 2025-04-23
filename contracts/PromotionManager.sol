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

// contract Snowballv5 {
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
//         bool loading; 
//     }

//     struct SnowballReceipt {
//         uint256 promotionID;
//         uint256 effectivePricePaid; 
//         uint256 tickets; 
//         address owner; 
//     }

//     struct DrawingReceipt {
//         uint256 promotionID; 
//         uint256 participantNumber;
//         uint256 redeemableAmount;
//         address owner; 
//         bool winner; 
//     }

//     struct VRFRequestContext {
//         uint256 drawingID;
//         uint256 cohort;
//     }
    

//     /* State Variables */
//     uint256 public snowballIDs = 1; 
//     uint256 public drawingIDs = 1; 
//     uint256 public promotionReceiptIDs = 1;
//     uint256 public constant MINIMUM_PRICE = 5 * 10 ** 6;
//     uint256 public constant MINIMUM_DURATION = 900; 
//     uint256 public commission = 25; // basis points (divided by 10,000)
//     address payable public bank;
//     address public owner; 
//     address public s_forwarderAddress; 
//     address public WCProviderAddress; 
//     uint256[] public activeDrawingsByID;
//     uint256[] public activeSnowballsByID;
//     uint256[]  public loadingDrawings; 
//     mapping(uint256 => uint256) snowballIDToActiveIndex;
//     mapping(uint256 => uint256) drawingIDToActiveIndex;
//     mapping(uint256 => Snowball) public Snowballs;
//     mapping(uint256 => Drawing) public Drawings;
//     mapping(uint256 => SnowballReceipt) public SnowballReceipts;
//     mapping(uint256 => DrawingReceipt) public DrawingReceipts;
//     mapping(uint256 => VRFRequestContext) public VRFRequestContexts;
//     mapping (address => uint256[]) public addressToActiveSnowballs;
//     mapping (address => uint256[]) public addressToInactiveSnowballs;
//     mapping(address => uint256[]) public addressToActiveDrawings;
//     mapping(address => uint256[]) public addressToInactiveDrawings;
//     mapping (address => uint256[]) public addressToSnowballReceiptIDs;
//     mapping(address => uint256) public userTotalDebt; 
//     mapping(address => uint256[]) public userOutstandingLoans; 
//     mapping(address => uint256) public redeemableRewards; 
//     mapping(uint256 => mapping(uint256 => uint256)) drawingParticipantsToReceipts; 
    


//     /* State Variables */
//     VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    
//     uint16 private constant REQUEST_CONFIRMATIONS = 3;
//     uint32 private immutable i_callbackGasLimit;
//     uint32 private constant NUM_WORDS = 1;
//     uint64 private immutable i_subscriptionId;
//     uint256 private s_lastTimeStamp;
//     uint256 private immutable i_interval;
//     bytes32 private immutable i_gasLane;
//     ISnowballWorkingCapital public snowballWorkingCapital; 
//     ILoanFactory public loanFactory; 
//     IERC20 public usdcToken; // Declare the USDC token contract
    

//     constructor(address _usdcToken) {
//         owner = msg.sender; // Set the owner to the contract deployer
//         bank = payable(owner);
//         usdcToken = IERC20(_usdcToken); // Initialize the USDC token contract
//     }

//     modifier onlyOwner() {
//         require(msg.sender == owner, "NotOwner");
//         _;
//     }

//     function setBank(address payable newBank) external onlyOwner {
//         bank = payable(newBank);
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
//         Drawing storage drawing = Drawings[drawingIDs];
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


//         activeDrawingsByID.push(drawingIDs); 
//         drawingIDToActiveIndex[drawingIDs] = addressToActiveDrawings[msg.sender].length; 
//         addressToActiveDrawings[msg.sender].push(drawingIDs);
//         drawingIDs += 1; 
//         return drawingIDs;
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
//         usdcToken.transferFrom(msg.sender, bank, commissionAmount); //pay commissions
//         payOwner(drawing.owner, toSeller - commissionAmount); //pay seller

//         //Mint DrawingReceipts
//         for(uint256 i =0; i<numTickets; i++) {
//             DrawingReceipt storage drawingReceipt = DrawingReceipts[promotionReceiptIDs+i];
//             drawingReceipt.owner = msg.sender;
//             drawingReceipt.promotionID = drawingID;
//             drawingReceipt.participantNumber = drawing.numParticipants + 1 + i; 
//             drawingParticipantsToReceipts[drawingID][drawing.numParticipants +1+ i] = promotionReceiptIDs +i;
//         }
//         promotionReceiptIDs += numTickets;
//         drawing.numParticipants+= numTickets; 
//     }

//     function initiateDrawing(uint256 _drawingID, uint256 _cohort) public  {
//         require(drawingEligibility(_drawingID), "Ineligible");         
//         Drawings[_drawingID].loading = true; 

//         uint256 requestId = i_vrfCoordinator.requestRandomWords(
//             i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, 1
//         );
//         VRFRequestContext storage context = VRFRequestContexts[requestId];
//         context.drawingID = _drawingID;
//         context.cohort = _cohort; 
//     }

//     function drawingEligibility(uint256 drawingID) public view returns (bool) {
//         Drawing storage drawing = Drawings[drawingID];
//         uint256 cohort = getReceiptCohort(drawingID); 
//         bool eligibility = true; 
//         if(drawing.loading || drawing.winners[cohort]!=0 || drawing.numParticipants < drawing.cohortSize*(1+cohort)) {
//             eligibility=false; 
//         }
//         return eligibility; 
//     }

//     function getReceiptCohort(uint256 drawingReceiptID) public view returns(uint256) {
//         DrawingReceipt storage drawingReceipt = DrawingReceipts[drawingReceiptID];
//         Drawing storage drawing = Drawings[drawingReceipt.promotionID];
//         require(drawingReceiptID!= 0 && drawingReceipt.promotionID != 0,  "inv");
//         uint256 receiptCohort = drawingReceipt.participantNumber / drawing.cohortSize; 
//         return receiptCohort; 
//     }
//     function ReceiptIsDrawn(uint256 drawingReceiptID) public view returns(bool) {
//         Drawing storage drawing = Drawings[DrawingReceipts[drawingReceiptID].promotionID];
//         uint256 receiptCohort = getReceiptCohort(drawingReceiptID); 
//         bool drawn;
//         if (drawing.winners[receiptCohort] != 0) {
//             drawn = true; 
//         }
//         return drawn; 
//     }
    

//     //Should be external? add override
//     function fulfillRandomWords(uint256 requestID, uint256[] memory randomWords) internal  {
//         VRFRequestContext storage context = VRFRequestContexts[requestID];
//         Drawing storage drawing = Drawings[context.drawingID];
//         uint256 winner = (context.cohort*drawing.cohortSize) + 1 + (randomWords[0]%drawing.cohortSize);
//         drawing.winners[context.cohort] = winner; 
//         uint256 winningReceiptID = drawingParticipantsToReceipts[context.drawingID][winner];
//         DrawingReceipt storage winningReceipt = DrawingReceipts[winningReceiptID];
//         winningReceipt.winner = true;
//         winningReceipt.redeemableAmount = drawing.rebateAmount*drawing.cohortSize;
//         //drawing.custodyBalance -= drawing.rebateAmount*drawing.cohortSize;
//         drawing.loading = false; 
//     }

//     function redeemDrawingTicket(uint256 drawingReceiptID) public {
//         DrawingReceipt storage drawingReceipt = DrawingReceipts[drawingReceiptID];
//         uint256 redeemableAmount = drawingReceipt.redeemableAmount;
//         if(redeemableAmount > 0) {
//             usdcToken.transfer(drawingReceipt.owner, redeemableAmount);
//             drawingReceipt.redeemableAmount =0; 
//         }
//         Drawing storage drawing = Drawings[drawingReceipt.promotionID];
//         drawing.custodyBalance -= redeemableAmount;
//     }


//     function redeemMultipleDrawings(uint256[] calldata drawingReceiptList) public {
//         uint256 redeemable; 
//         for(uint256 i = 0; i < drawingReceiptList.length; i ++) {
//             DrawingReceipt storage drawingReceipt = DrawingReceipts[drawingReceiptList[i]]; 
//             require(drawingReceipt.owner == msg.sender, "Not Owner");
//             redeemable += drawingReceipt.redeemableAmount;
//             Drawing storage drawing = Drawings[drawingReceipt.promotionID];
//             drawing.custodyBalance -= drawingReceipt.redeemableAmount;
//             drawingReceipt.redeemableAmount = 0; 
//         }
//         usdcToken.transfer(msg.sender, redeemable);
//     }

//     function retrieveExcessDrawingCustody(uint256 drawingID) public {
//         Drawing storage drawing = Drawings[drawingID];
//         uint256 excessCustody;
//         if((block.timestamp > drawing.duration + drawing.startTime || drawing.maxSlots == drawing.numParticipants) && !drawing.returnedCustody) {
//             excessCustody = (drawing.numParticipants % drawing.cohortSize)*drawing.rebateAmount; 
//             drawing.custodyBalance -= excessCustody;
//             uint256 commissionAmount = calculateCommission(excessCustody); //Commission is on all proceeds to sellers. 
//             usdcToken.transfer(bank, commissionAmount);
//             payOwner(drawing.owner, excessCustody-commissionAmount);
//             drawing.returnedCustody = true; 

//         }
//     }
    
//     function createSnowball(
//         uint256 _maxSlots,
//         uint256 _duration,
//         uint256[] memory _cohortPrices,
//         uint256[] memory _thresholds
//     ) public returns(uint256) {
//         if (_cohortPrices.length -1 != _thresholds.length || _cohortPrices.length < 1 || _cohortPrices.length > 5 || 
//         _thresholds[0] <=1 || _thresholds[_thresholds.length - 1]> _maxSlots || _thresholds[0]> _maxSlots ||_duration <= MINIMUM_DURATION ||
//         _cohortPrices[_cohortPrices.length-1] <MINIMUM_PRICE) {
//             revert InvalidConfig(); 
//         }
//         // Check that _cohortPrices is strictly decreasing and _thresholds is strictly increasing
//         for (uint256 i = 0; i < _thresholds.length; i++) {
//             if (_cohortPrices[i] <= _cohortPrices[i + 1]) {
//                 revert InvalidConfig();
//             }
//             if (i > 0 && _thresholds[i] <= _thresholds[i - 1]) {
//                 revert InvalidConfig();
//             }
//         }

//         // Initialize a new snowball contract and store it in storage
//         Snowball storage snowball = Snowballs[snowballIDs];
//         snowball.maxSlots = _maxSlots;
//         snowball.duration = _duration;
//         snowball.thresholds = _thresholds;
//         snowball.owner = payable(msg.sender);
//         snowball.startTime = block.timestamp;
//         snowball.numParticipants = 0;
//         snowball.custodyBalance = 0;
//         snowball.cohortPrices = _cohortPrices;

//         activeSnowballsByID.push(snowballIDs); 
//         snowballIDToActiveIndex[snowballIDs] = addressToActiveSnowballs[msg.sender].length; 
//         addressToActiveSnowballs[msg.sender].push(snowballIDs);
//         snowballIDs += 1; 
//         return snowballIDs;
//     }


//     function getSnowballCurrentPrice(uint256 snowballID) public view returns (uint256) {
//         Snowball memory snowball = Snowballs[snowballID]; 
//         // Loop through the prices and stop when you get a price that is decreasing
//         for (uint256 i = 1; i < snowball.cohortPrices.length; i++) {
//             if (snowball.cohortPrices[i] < snowball.cohortPrices[i - 1]) {
//                 // Return the last price before the decrease
//                 return snowball.cohortPrices[i - 1];
//             }
//         }

//         // If all prices are strictly decreasing, return the last price
//         return snowball.cohortPrices[snowball.cohortPrices.length - 1];
//     }

//     function getSnowballUpdatedPrice(uint256[] memory cohortPrices, uint256[] memory thresholds, uint256 updatedParticipants) public pure returns(uint256) {
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

//     function updateSnowballPrices(uint256 snowballID, uint256 updatedPrice) private {
//         for (uint256 i =0; i < Snowballs[snowballID].cohortPrices.length; i++) {
//             if (Snowballs[snowballID].cohortPrices[i] > updatedPrice) {
//                 Snowballs[snowballID].cohortPrices[i] = updatedPrice; 
//             }
//         }
//     }

    

//     function joinSnowball(uint256 snowballID, uint256 numTickets) public {
//         Snowball memory snowball = Snowballs[snowballID]; 
//         if (snowball.duration + snowball.startTime < block.timestamp || snowball.numParticipants + numTickets > snowball.maxSlots) {
//             revert Promotion_Expired(); //not necessarily, maybe just too many tickets
//         }
//         uint256 newPrice = getSnowballUpdatedPrice(snowball.cohortPrices, snowball.thresholds, snowball.numParticipants + numTickets);
//         updateSnowballPrices(snowballID, newPrice);
//         uint256 minPrice = snowball.cohortPrices[snowball.cohortPrices.length-1]; 
//         uint256 custodyAmount = (newPrice - minPrice);
//         if(custodyAmount !=0) {
//             usdcToken.transferFrom(msg.sender, address(this), custodyAmount*numTickets); //place custody
//             Snowballs[snowballID].custodyBalance +=custodyAmount*numTickets; 
//         }
//         uint256 commissionAmount = calculateCommission(numTickets*minPrice); 
//         usdcToken.transferFrom(msg.sender, bank, commissionAmount); //pay commissions
//         payOwner(snowball.owner, numTickets*minPrice - commissionAmount);
//         Snowballs[snowballID].numParticipants +=numTickets; 

//         //Mint snowballReceipt
//         SnowballReceipt storage snowballReceipt = SnowballReceipts[promotionReceiptIDs]; 
//         snowballReceipt.promotionID = snowballID; 
//         snowballReceipt.effectivePricePaid = newPrice; 
//         snowballReceipt.owner = msg.sender; 
//         snowballReceipt.tickets = numTickets;

//         addressToSnowballReceiptIDs[msg.sender].push(promotionReceiptIDs); 
//         promotionReceiptIDs+=1; 
//     }


    
//     function retrieveExcessSnowballCustody(uint256 snowballID) public {
//         Snowball storage snowball = Snowballs[snowballID]; 
//         uint256 excessCustody;
//         //Check that the snowball has melted
//         if((block.timestamp > snowball.duration + snowball.startTime || snowball.maxSlots == snowball.numParticipants) && !snowball.returnedCustody) {
//             uint256 currentPrice = getSnowballCurrentPrice(snowballID );
//             excessCustody = (currentPrice-snowball.cohortPrices[snowball.cohortPrices.length-1]) * snowball.numParticipants; //This amount will be made available to sellers and their creditors
//             snowball.custodyBalance -= excessCustody; 
//             uint256 commissionAmount = calculateCommission(excessCustody); //Commission is on all proceeds to sellers. 
//             usdcToken.transfer(bank, commissionAmount);
//             payOwner(snowball.owner, excessCustody-commissionAmount);
//             snowball.returnedCustody = true; 
//         }
//     }

//     //Should be private?
//     function payOwner(address snowballOwner,  uint256 amount) private {
//         uint256 ownerDebt = userTotalDebt[snowballOwner]; 
//         if (ownerDebt == 0) {
//             usdcToken.transfer(snowballOwner, amount); 
//         }
//         else {
//             uint256 excess = payDebtHolders(snowballOwner, amount);
//             usdcToken.transfer(snowballOwner, excess); 
//         }
//     }

//     function snowballReceiptRedeemableAmount(uint256 snowballReceiptID) public view returns(uint256, uint256) {
//         SnowballReceipt memory snowballReceipt = SnowballReceipts[snowballReceiptID]; 
//         uint256 currentPrice = getSnowballCurrentPrice(snowballReceipt.promotionID); 
//         return (((snowballReceipt.effectivePricePaid-currentPrice) * snowballReceipt.tickets), currentPrice);
//     }

//     function redeemSnowballReceipt(uint256 snowballReceiptID) public {
//         SnowballReceipt storage snowballReceipt = SnowballReceipts[snowballReceiptID]; 
//         require(snowballReceipt.owner == msg.sender, "Not Owner");
//         (uint256 redeemableAmount, uint256 newEffectivePrice) = snowballReceiptRedeemableAmount(snowballReceiptID);
//         usdcToken.transfer(snowballReceipt.owner, redeemableAmount); 
//         snowballReceipt.effectivePricePaid = newEffectivePrice; 
//         Snowballs[snowballReceipt.promotionID].custodyBalance -= redeemableAmount;
//     }

//     function redeemMultipleSnowballs(uint256[] calldata snowballReceiptList) public {
//         uint256 redeemable; 
//         for(uint256 i = 0; i < snowballReceiptList.length; i ++) {
//             SnowballReceipt storage snowballReceipt = SnowballReceipts[snowballReceiptList[i]]; 
//             require(snowballReceipt.owner == msg.sender, "Not Owner");
//             (uint256 redeemableAmount, uint256 newEffectivePrice) = snowballReceiptRedeemableAmount(snowballReceiptList[i]);
//             snowballReceipt.effectivePricePaid = newEffectivePrice; 
//             Snowballs[snowballReceipt.promotionID].custodyBalance -= redeemableAmount;
//             redeemable +=redeemableAmount;
//         }
//         usdcToken.transfer(msg.sender, redeemable);
//     }



//     //Calculates the commissions given the non-custody amount
//     function calculateCommission(uint256 totalAmount) internal view returns (uint256) { //should be internal
//         uint256 commissionAmount = totalAmount *commission/10000; 
//         return (commissionAmount);
//     }


//     function payDebtHolders(address debtor, uint256 availableAmount) private returns(uint256) {
//         uint256[] storage outstandingLoans = userOutstandingLoans[debtor];
//         uint256 closed;
//         uint256 debtSpending; 
//         for (uint256 i =0; i < outstandingLoans.length; i++) {
//             (, ,uint256 loanRemainingAmount, uint256 loanRedeemableAmount) = snowballWorkingCapital.Loans(outstandingLoans[i]);
//             uint256 newlyRedeemableAmount =  Math.min(availableAmount, loanRemainingAmount-loanRedeemableAmount);
//             availableAmount -=newlyRedeemableAmount;
//             debtSpending += newlyRedeemableAmount;
//             snowballWorkingCapital.repayDebt(outstandingLoans[i], newlyRedeemableAmount);
            
//             if (loanRemainingAmount == loanRedeemableAmount + newlyRedeemableAmount) {
//                 // This loan is fully paid off
//                 closed++;
//             }  
//             else if(closed >0) {
//                 for(uint j =0; j < outstandingLoans.length-closed; j++) {
//                     outstandingLoans[j] = outstandingLoans[j+closed];
//                 }
//                 break;
//             }
//         }
//         // Remove the closed loans by popping the last 'closed' elements
//         for (uint256 i =0; i < closed; i++) {
//             outstandingLoans.pop(); 
//         }

//         usdcToken.approve(WCProviderAddress, usdcToken.allowance(address(this), WCProviderAddress) + debtSpending);
//         userTotalDebt[debtor] -=debtSpending;

//         return availableAmount;

//     }

//     function checkUpkeep() public {
//         bool upkeepNeeded = false;
//         // Loop to check for snowballs that need closing
//         uint256 snowballCloseCounter;
//         for (uint256 i = 0; i < activeSnowballsByID.length; i++) {
//             if (block.timestamp - Snowballs[activeSnowballsByID[i]].duration >= Snowballs[activeSnowballsByID[i]].startTime || Snowballs[activeSnowballsByID[i]].numParticipants == Snowballs[activeSnowballsByID[i]].maxSlots) {
//                 snowballCloseCounter += 1;
//                 upkeepNeeded = true;
//                 console.log("Snowball ID %s close.", activeSnowballsByID[i]);
//             }
//         }

//         // Loop to check for drawings that need closing or updating
//         uint256 drawingCloseCounter;
//         for (uint256 i = 0; i < activeDrawingsByID.length; i++) {
//             if (block.timestamp - Drawings[activeDrawingsByID[i]].duration >= Drawings[activeDrawingsByID[i]].startTime || Drawings[activeDrawingsByID[i]].numParticipants == Drawings[activeDrawingsByID[i]].maxSlots) {
//                 drawingCloseCounter += 1;
//                 upkeepNeeded = true;
//                 console.log("Drawing ID %s close.", activeDrawingsByID[i]);
//             }
//         }

//         // Initialize arrays of upkeeps
//         uint256[] memory snowballsToClose = new uint256[](snowballCloseCounter);
//         uint256 snowballCloseIndex;
//         uint256[] memory drawingsToClose = new uint256[](drawingCloseCounter);
//         uint256 drawingCloseIndex; 

//         // Loop again to fill the arrays
//         for (uint256 i = 0; i < activeSnowballsByID.length; i++) {
//             if (block.timestamp - Snowballs[activeSnowballsByID[i]].duration >= Snowballs[activeSnowballsByID[i]].startTime || Snowballs[activeSnowballsByID[i]].numParticipants == Snowballs[activeSnowballsByID[i]].maxSlots){
//                 snowballsToClose[snowballCloseIndex] = i; 
//                 snowballCloseIndex += 1;
//                 console.log("Adding Snowball ID %s to close list.", activeSnowballsByID[i]);
//             } 
//         }

//         for (uint256 i = 0; i < activeDrawingsByID.length; i++) {
//             if (block.timestamp - Drawings[activeDrawingsByID[i]].duration >= Drawings[activeDrawingsByID[i]].startTime || Drawings[activeDrawingsByID[i]].numParticipants == Drawings[activeDrawingsByID[i]].maxSlots) {
//                 drawingsToClose[drawingCloseIndex] = i; 
//                 drawingCloseIndex += 1;
//                 console.log("Adding Drawing ID %s to close list.", activeDrawingsByID[i]);
//             } 
//         }  

//         // Encode the data to be passed to performUpkeep
//         bytes memory performData = abi.encode(snowballsToClose, drawingsToClose);
//         performUpkeep(performData);
//         //return (upkeepNeeded, performData);
//     }
//     //if ID is 0, continue. 
//     function performUpkeep(bytes memory performData) public {
//         if(msg.sender != s_forwarderAddress) {
//             revert NotApproved(); 
//         }
        
//         (uint256[] memory snowballsToClose, uint256[] memory drawingsToClose) = abi.decode(
//             performData,
//             (uint256[], uint256[])
//         );

//         // Close snowballs
//         uint256 i = snowballsToClose.length;
//         while (i > 0) {
//             i--;
//             uint256 promotionID = activeSnowballsByID[snowballsToClose[i]];
//             console.log("Closing Snowball ID %s.", promotionID);

//             //Remove snowball from list of active snowballs
//             activeSnowballsByID[snowballsToClose[i]] = activeSnowballsByID[activeSnowballsByID.length - 1];
//             activeSnowballsByID.pop();
//             console.log("Closed ", promotionID);
           
//             //Handle user specific active snowballs
//             uint256[] storage userActiveSnowballs = addressToActiveSnowballs[Snowballs[promotionID].owner];
//             uint256 indexToRemove =  snowballIDToActiveIndex[promotionID];
//             if (userActiveSnowballs.length > 1) {
//                 // Swap the snowball with the last one in the user's list
//                 userActiveSnowballs[indexToRemove] = userActiveSnowballs[userActiveSnowballs.length - 1];

//                 // Update the mapping for the swapped snowball's new index
//                 snowballIDToActiveIndex[userActiveSnowballs[indexToRemove]] = indexToRemove;
//             }
//             // Pop the last element from the user's active snowballs list
//             userActiveSnowballs.pop();
//             addressToInactiveSnowballs[Snowballs[promotionID].owner].push(promotionID); 
//         }

//         //close drawings
//         i = drawingsToClose.length;
//         while (i > 0) {
//             i--;
//             uint256 promotionID = activeDrawingsByID[drawingsToClose[i]];
//             console.log("Closing Drawing ID %s.", promotionID);

//             //Remove drawing from list of active drawings
//             activeDrawingsByID[drawingsToClose[i]] = activeDrawingsByID[activeDrawingsByID.length - 1];
//             activeDrawingsByID.pop();
//             console.log("Closed ", promotionID);
           
//             //Handle user specific active drawings
//             uint256[] storage userActiveDrawings = addressToActiveDrawings[Drawings[promotionID].owner];
//             uint256 indexToRemove =  drawingIDToActiveIndex[promotionID];
//             if (userActiveDrawings.length > 1) {
//                 // Swap the dra with the last one in the user's list
//                 userActiveDrawings[indexToRemove] = userActiveDrawings[userActiveDrawings.length - 1];

//                 // Update the mapping for the swapped drawing's new index
//                 drawingIDToActiveIndex[userActiveDrawings[indexToRemove]] = indexToRemove;
//             }
//             // Pop the last element from the user's active drawings list
//             userActiveDrawings.pop();
//             addressToInactiveDrawings[Drawings[promotionID].owner].push(promotionID); 
//         }
//     }

//     function reduceDrawingCustodyBalance(uint256 drawingID, uint256 reductionAmount) public {
//         return; 
//     }
//     function isOwner(uint256 promotionID, uint)


//     // / @notice Set the address that `performUpkeep` is called from
//     // / @dev Only callable by the owner
//     // / @param forwarderAddress the address to set
//     //MAKE THIS ONLY OWNER
//     // function setForwarderAddress(address forwarderAddress) external onlyOwner {
//     //     s_forwarderAddress = forwarderAddress;
//     // }

//     function setWorkingCapitalProvider(address _WCProviderAddress) external onlyOwner {
//         WCProviderAddress = _WCProviderAddress; 
//         snowballWorkingCapital = ISnowballWorkingCapital(_WCProviderAddress); 
//     }

//     function setLoanFactory(address _loanFactoryAddress) external onlyOwner {
//         loanFactory = ILoanFactory(_loanFactoryAddress); 
//     }

//     function getActiveSnowballsByOwner(address user) public view returns (uint256[] memory) {
//         return addressToActiveSnowballs[user];
//     }

//     function addUserDebt(address debtor, uint256 totalDebtAmount, uint256 loanID) external {
//         if(msg.sender != WCProviderAddress) {
//             revert NotApproved(); 
//         }
//         userOutstandingLoans[debtor].push(loanID); 
//         userTotalDebt[debtor] += totalDebtAmount; 
//     }

// }
