// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error Promotion_Expired();
error InvalidConfig(); 
error NotApproved();

event DrawingCreated(address indexed owner, uint256 indexed promotionID, address indexed erc20Token, uint256 thresholdAmount, uint256 endTime, uint256 rafflePrizeBPs, uint256 minimumOrderSize, bool mintsNFTs);
event DrawingCustodyRedeemed(uint256 indexed promotionID, uint256 redeemedAmount); 
event DrawingCancelled(uint256 indexed promotionID, uint256 numberOfParticipants);
event DrawingReceiptRedeemed(uint256 indexed tokenID, uint256 indexed promotionID, uint256 cohortNumber, uint256 redeemedAmount); 
event DrawingReceiptMinted(address indexed buyer, uint256 indexed promotionID, uint256 indexed participantNumber, uint256 cohort, uint256 receiptID, uint256 purchaseAmount, uint256 orderID);
event RaffleWinner(uint256 indexed promotionID, uint256 cohort, uint256 tokenID, uint256 prize,  uint256 randomWord); 
event RafflesInitiated(uint64[] promotionIDs, uint256 indexed vrfRequestID, address indexed initiator, uint16[] cohorts); //initiators should be reimbursed more in potential air-drops

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SatsumePromotion.sol";
import "../../interfaces/IISOManager.sol"; 

contract DrawingManager is VRFConsumerBaseV2, SatsumePromotion {

    struct Drawing {
        uint256 endTime;  
        uint256 thresholdAmount;
        uint256 rafflePrizeBPs;    
        address owner;          
        bool returnedCustody;    
        bool mintsNFTs;    
        bool soldOut;     
        bool cancelledDrawing; 
        uint256[] raffleAmounts;        
        uint256 minimumOrderSize;
        uint256 activeCohort;       
        address erc20Token;      
    }

    struct DrawingReceipt {
        uint256 drawingID;
        uint256 cohortNumber;
        uint256 raffleContribution;
        uint256 redeemableAmount; 
    }

    struct VRFRequestContext {
        uint64[] drawingIDArray; 
        uint16[] cohorts;
        uint256[] randomWords; 
    }

    uint256 public drawingIDs = 1;// type(uint256).max / 10 * 2 + 1;
    uint256 public constant MINIMUM_DURATION = 900; 
    address public URISetter;
    bool allowCustomReceipts; 


    mapping(uint256 => DrawingReceipt) public DrawingReceipts;
    mapping(uint256 => Drawing) public Drawings;
    mapping(uint256 => VRFRequestContext) private vrfRequestIDtoContext; //must this be private? 
    mapping(uint256=> mapping(uint256 => bool)) public raffleInitiatedBool;
    mapping(uint256 => mapping(uint256 => uint256[])) public drawingIDCohortToReceipts; 

    /* State Variables */
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    
    IISOManager public isoManager;
    address public isoManagerAddress; 
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint64 private immutable i_subscriptionId;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_gasLane;

    constructor(
        address vrfCoordinatorV2,
        address _receiptManagerAddress,
        address _merchantManagerAddress, 
        address _isoManagerAddress, 
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) { 
        contractOwner = msg.sender; // Set the owner to the contract deployer
        receiptManagerAddress = _receiptManagerAddress;  
        receiptManager = IReceiptManager(_receiptManagerAddress);
        merchantManagerAddress = _merchantManagerAddress;  
        merchantManager = IMerchantManager(_merchantManagerAddress);
        isoManagerAddress = _isoManagerAddress;
        isoManager = IISOManager(_isoManagerAddress);
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function createDrawing(
        uint256 _duration,
        uint256 _thresholdAmount,
        uint256 _rafflePrizeBPs, 
        uint256 _minimumOrderSize,
        uint16 _numberOfRaffles, 
        address _owner,
        address _erc20Token, 
        bool _mintsNFTs
    ) public onlyApprovedOperators(_owner) {
        if ( _duration < MINIMUM_DURATION || _minimumOrderSize < _thresholdAmount || _rafflePrizeBPs >= 10000) {
            revert InvalidConfig();
        }

        // Initialize a new drawing contract and store it in storage
        Drawing storage drawing = Drawings[drawingIDs];
        drawing.owner = payable(_owner);
        drawing.endTime = block.timestamp + _duration;
        drawing.thresholdAmount = _thresholdAmount; 
        drawing.rafflePrizeBPs = _rafflePrizeBPs; 
        drawing.minimumOrderSize = _minimumOrderSize; 
        drawing.erc20Token = _erc20Token; 
        drawing.mintsNFTs = _mintsNFTs;
        drawing.raffleAmounts = new uint256[](_numberOfRaffles);

        emit DrawingCreated(_owner, drawingIDs, _erc20Token, _thresholdAmount, _duration + block.timestamp, _rafflePrizeBPs, _minimumOrderSize, _mintsNFTs); 
        addressToPromotions[_owner].push(drawingIDs);
        if (_mintsNFTs) {
            receiptManager.setPromotionOwner(drawingIDs, _owner); 
        }
        drawingIDs+=1; 
    }
    //OrderID is an optional parameter. Can put anything there
    function joinPromotion(uint256 drawingID, uint256 purchaseAmount, uint256 orderID, address buyer) public override {
        Drawing memory drawing = Drawings[drawingID];
        uint256 numParticipants = promotionIDToReceiptIDs[drawingID].length;

        // Check if the promotion is expired or slots are full
        if (drawing.soldOut ||  drawing.endTime < block.timestamp) {
            revert Promotion_Expired();
        } 
        
        //Potential overflow here *********************************************************
        uint256 sharedTotal = purchaseAmount * drawing.rafflePrizeBPs / 10000; 
        uint256 commissionAmount = (purchaseAmount - sharedTotal) * commission / 10000;

        // Transfer funds
        isoManager.payStore(drawing.owner, (purchaseAmount - commissionAmount - sharedTotal), commissionAmount, sharedTotal, drawing.erc20Token, buyer); 

        // Update commission balances
        earnedCommissions[drawing.erc20Token] += commissionAmount;

        // Mint NFT receipts and log details
        uint256 receiptID;
        if (drawing.mintsNFTs) {
            receiptID = receiptManager.mintReceipts(
                buyer,
                drawingID,
                numParticipants + 1,
                1
            );
        } else {
            receiptID = receiptManager.incrementReceiptIDs(1);
        }

        DrawingReceipt storage drawingReceipt = DrawingReceipts[receiptID];
        drawingReceipt.drawingID = drawingID; 
        drawingReceipt.raffleContribution = sharedTotal; 

        // Directly push to storage array
        promotionIDToReceiptIDs[drawingID].push(receiptID);
        drawingIDCohortToReceipts[drawingID][drawing.activeCohort].push(receiptID); 

        if(drawing.raffleAmounts[drawing.activeCohort] >= drawing.thresholdAmount) {
            if(drawing.activeCohort == drawing.raffleAmounts.length-1) {
                drawing.soldOut = true;
            }
            else {
                drawing.activeCohort += 1; 
            }
        }

        // Handle unminted receipt ownership
        if (!drawing.mintsNFTs) {
            unmintedReceiptsToOwners[receiptID] = buyer;
        }
        
        // Update the number of participants
        emit DrawingReceiptMinted(buyer, drawingID, numParticipants +1, drawing.activeCohort, receiptID, purchaseAmount, orderID);
    }

    function drawingEligibility(uint256 drawingID, uint256 cohort) public view returns (bool) {
        Drawing storage drawing = Drawings[drawingID];
        if(drawing.raffleAmounts[cohort] < drawing.thresholdAmount || raffleInitiatedBool[drawingID][cohort] == true) {
            return false;
        }
        else {
            return true;
        } 
    } 

    function initiateDrawings(uint64[] calldata arrayOfDrawingIDs, uint16[] calldata arrayOfcohorts) public {
        // Check array lengths match
        require(arrayOfDrawingIDs.length == arrayOfcohorts.length, "Array length mismatch");
        require(arrayOfDrawingIDs.length <= 5, "Exceed length");
        require(arrayOfDrawingIDs.length > 0, "Zero length");

        // Pre-check eligibility for all entries
        for (uint256 i = 0; i < arrayOfDrawingIDs.length; i++) {
            require(drawingEligibility(arrayOfDrawingIDs[i], arrayOfcohorts[i]), "Ineligible entry");
        }

        // Process each drawingID and cohort
        for (uint256 i = 0; i < arrayOfDrawingIDs.length; i++) {
            raffleInitiatedBool[arrayOfDrawingIDs[i]][arrayOfcohorts[i]] = true;
        }

        // Convert length to uint32 for VRF call
        uint32 numWords = uint32(arrayOfDrawingIDs.length);

        // Request randomness
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            numWords // Number of random words to request (adjust if needed)
        );

        // Create storage reference to the context
        VRFRequestContext storage context = vrfRequestIDtoContext[requestId];

        // Manually copy arrays from calldata to storage
        context.drawingIDArray = arrayOfDrawingIDs; // This copies elements
        context.cohorts = arrayOfcohorts; // This copies elements
        
        //emit event
        emit RafflesInitiated(arrayOfDrawingIDs, requestId, msg.sender, arrayOfcohorts);
    }

    function fulfillRandomWords(
        uint256 requestId, 
        uint256[] memory randomWords
    ) internal override {
        VRFRequestContext storage context = vrfRequestIDtoContext[requestId];
        // Ensure we have enough random words
        require(
            randomWords.length == context.drawingIDArray.length, 
            "Random words length mismatch"
        );
        
        // Process each drawing/cohort combination
        for (uint i = 0; i < context.drawingIDArray.length; i++) {
            uint256 drawingID = context.drawingIDArray[i];
            uint256 cohort = context.cohorts[i];
            uint256 randomWord = randomWords[i];
            uint256[] memory cohortReceipts = drawingIDCohortToReceipts[drawingID][cohort]; 
            
            // Calculate winner position
            uint256 x = randomWord % Drawings[drawingID].raffleAmounts[cohort];
            uint256 sum; 
            uint256 winningIndex;
            for (uint256 j = 0; j < cohortReceipts.length; j ++) {
                sum += DrawingReceipts[cohortReceipts[j]].raffleContribution;
                if ( sum > x) {
                    winningIndex = j;
                    break;
                } 
           }
            uint256 winningReceiptID = cohortReceipts[winningIndex];            
            
            // Update receipt
            DrawingReceipt storage drawingReceipt = DrawingReceipts[winningReceiptID];
            drawingReceipt.redeemableAmount = Drawings[drawingID].raffleAmounts[cohort];
            
            // Emit event for this winner
            emit RaffleWinner(
                drawingID,
                cohort,
                winningReceiptID,
                Drawings[drawingID].raffleAmounts[cohort],
                randomWord
            );
        }
        // Optional: Clean up storage to save gas
        delete vrfRequestIDtoContext[requestId];
    }


    function redeemDrawingReceipts(uint256[] calldata receiptIDs) external {
        uint256 redeemableAmount; 
        address erc20Token = Drawings[DrawingReceipts[receiptIDs[0]].drawingID].erc20Token; //erc20 address of the first token
        for(uint256 i =0; i < receiptIDs.length; i++) {
            DrawingReceipt memory drawingReceipt = DrawingReceipts[receiptIDs[i]];
            Drawing storage drawing = Drawings[drawingReceipt.drawingID];
            require(erc20Token == drawing.erc20Token, "Invalid"); 
            if(drawing.mintsNFTs) {
                require((receiptManager.ownerOf(receiptIDs[i]) == msg.sender), "Not owned");
            }
            else {
                require((unmintedReceiptsToOwners[receiptIDs[i]] == msg.sender), "Not owned");
            }            
            if(drawingReceipt.redeemableAmount >0) {
                redeemableAmount += drawingReceipt.redeemableAmount;
                DrawingReceipts[receiptIDs[i]].redeemableAmount = 0; 
                emit DrawingReceiptRedeemed(receiptIDs[i], drawingReceipt.drawingID, drawingReceipt.cohortNumber, drawingReceipt.redeemableAmount); 
            }
            //For cancelled drawings, the last cohort gets to receive their raffle contributions back
            else if(drawing.cancelledDrawing && drawing.raffleAmounts[drawingReceipt.cohortNumber] < drawing.thresholdAmount) {
                redeemableAmount += drawingReceipt.raffleContribution;
                DrawingReceipts[receiptIDs[i]].raffleContribution = 0;
                emit DrawingReceiptRedeemed(receiptIDs[i], drawingReceipt.drawingID, drawingReceipt.cohortNumber, drawingReceipt.raffleContribution); 
            }
        }
        if(redeemableAmount !=0) {
            IERC20(erc20Token).transfer(
                msg.sender,
                redeemableAmount
            );
        }
    }


    function cancelDrawing(uint256 drawingID) external {
        Drawing storage drawing = Drawings[drawingID];
        if (!merchantManager.isApprovedOperator(msg.sender, drawing.owner)) {
            revert NotApproved(); 
        }
        if (drawing.endTime > block.timestamp) {
            drawing.endTime = 0; 
            drawing.cancelledDrawing = true; 
            drawing.returnedCustody = true; 
        }
    }

    function retrieveExcessDrawingCustody(uint256 drawingID) public {
        Drawing storage drawing = Drawings[drawingID];

        require(block.timestamp > drawing.endTime && drawing.endTime != 0, "Ineligible");
        require(!drawing.returnedCustody, "Already Returned");

        if(drawing.raffleAmounts[drawing.activeCohort] < drawing.thresholdAmount && !drawing.returnedCustody) {
            drawing.returnedCustody = true;
            // Pay the contract  owner the remaining amount 
            IERC20(drawing.erc20Token).transfer(contractOwner, drawing.raffleAmounts[drawing.activeCohort]); 
            earnedCommissions[drawing.erc20Token] += drawing.raffleAmounts[drawing.activeCohort];
            emit DrawingCustodyRedeemed(drawingID, drawing.raffleAmounts[drawing.activeCohort]); 
        }
    }


    function setPromotionURI(uint256 promotionID, string calldata newURIRoot) external override {
        Drawing storage drawing = Drawings[promotionID];
        
        // Common validation checks
        if (!drawing.mintsNFTs) revert NotCustomURI();
        if (bytes(receiptManager.customURIRoot(promotionID)).length != 0) revert URIAlreadSet();
        
        // Permission checks based on allowCustomReceipts flag
        if (allowCustomReceipts) {
            if (!merchantManager.isApprovedOperator(msg.sender, drawing.owner)) revert NotApproved();
        } else {
            if (msg.sender != URISetter) revert NotApproved();
        }
        
        // Update URI
        receiptManager.modifyPromotionURI(promotionID, newURIRoot);
    }

    function setRoyalty(uint256 promotionID, uint256 basisPoints) external override {
        Drawing storage drawing = Drawings[promotionID]; 
        if (!merchantManager.isApprovedOperator(msg.sender, drawing.owner)) {
            revert NotApproved(); 
        }
        receiptManager.setRoyalty(promotionID, basisPoints);
    }

    function setURISetter(address newURISetter) onlyOwner public{
        URISetter = newURISetter; 
    }
}