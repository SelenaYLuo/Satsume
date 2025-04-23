// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error Promotion_Expired();
error InvalidConfig(); 
error NotApproved();

event SnowballCreated(address indexed owner, uint256 indexed snowballID, address indexed erc20Token, uint256 maxSlots, uint256 endTime, uint256[] thresholds, uint256[] cohortPrices, bool mintsNFTS);
event SnowballCustodyRedeemed(uint256 indexed snowballID, uint256 redeemedAmount); 
event SnowballCancelled(uint256 indexed snowballID, uint256 numberOfParticipants);
event SnowballReceiptRedeemed(uint256 indexed tokenID, uint256 indexed snowballID, uint256 redeemedAmount); 
event SnowballReceiptsMinted(address indexed joiner, uint256 indexed snowballID, uint256 firstParticipantNumber, uint256 firstTokenID, uint256 pricePaid, uint256 numTickets);

import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PromotionManagerv9.sol";

contract SnowballManager is PromotionManager {
    struct Snowball {
        uint256 maxSlots; 
        uint256 endTime;
        uint256[] thresholds;
        uint256[] cohortPrices; 
        address owner; 
        bool returnedCustody; 
        address erc20Token; 
        bool mintReceipts; 
    }

    struct SnowballReceipt {
        uint256 snowballID;
        uint256 effectivePricePaid;
    }

    

    uint256 public snowballIDs = 1;
    
    uint256 public constant MINIMUM_DURATION = 900; 

    mapping(uint256 => Snowball) public Snowballs;
    mapping(uint256 => SnowballReceipt) public SnowballReceipts;
    
    

    constructor(address _receiptManagerAddress, address _promotionsManagerAddress) { 
        contractOwner = msg.sender; // Set the owner to the contract deployer
        receiptManager = IReceiptManager(_receiptManagerAddress); 
        receiptManagerAddress = _receiptManagerAddress;
        promotionsManagerAddress = _promotionsManagerAddress;  
        promotionsManager = IPromotionsManager(_promotionsManagerAddress);
    }

    function createSnowball(
        uint256 _maxSlots,
        uint256 _duration,
        uint256[] calldata _cohortPrices,
        uint256[] calldata _thresholds,
        address _owner,
        address _erc20Token,
        bool _mintReceipts
    ) public {
        if (_cohortPrices.length -1 != _thresholds.length || 
            _cohortPrices.length < 2 || 
            _cohortPrices.length > 5 || 
            _thresholds[0] <=1 || 
            _thresholds[_thresholds.length - 1]> _maxSlots || 
            _duration < MINIMUM_DURATION ) {
            revert InvalidConfig(); 
        }
        if (!promotionsManager.isApprovedOperator(msg.sender, _owner)) {
            revert NotApproved(); 
        }

        // Check that _cohortPrices is strictly decreasing, and all values are nonzero
        for (uint256 i = 0; i < _cohortPrices.length; i++) {
            if (_cohortPrices[i] == 0) {
                revert InvalidConfig(); // Reject zero values in _cohortPrices
            }
            if (i != 0) {
                if (_cohortPrices[i] >= _cohortPrices[i - 1]) {
                    revert InvalidConfig(); // Ensure strictly decreasing order
                }
            }
        }

        // Check that _thresholds is strictly increasing
        if (_thresholds.length > 1) {
            for (uint256 i = 1; i < _thresholds.length; i++) {
                if (_thresholds[i] <= _thresholds[i - 1]) {
                    revert InvalidConfig(); // Ensure strictly increasing order
                }
            }
        }


        // Initialize a new snowball contract and store it in storage
        Snowball storage snowball = Snowballs[snowballIDs];
        snowball.maxSlots = _maxSlots;
        snowball.thresholds = _thresholds;
        snowball.owner = payable(_owner);
        snowball.endTime = block.timestamp +_duration;
        snowball.cohortPrices = _cohortPrices;
        snowball.erc20Token = _erc20Token;
        snowball.mintReceipts = _mintReceipts;  

        emit SnowballCreated(_owner, snowballIDs, _erc20Token, _maxSlots, _duration + block.timestamp, _thresholds, _cohortPrices, _mintReceipts);
        addressToPromotions[_owner].push(snowballIDs);
        if (_mintReceipts) {
            receiptManager.setPromotionOwner(snowballIDs, _owner); 
        }
        snowballIDs += 1; 
    }

    function joinSnowball(uint256 snowballID, uint256 numOrders) public {
        Snowball storage snowball = Snowballs[snowballID];
        uint256 numParticipants = promotionIDToReceiptIDs[snowballID].length;
        address erc20Token = snowball.erc20Token;

        if (numParticipants >= snowball.maxSlots ||  snowball.endTime < block.timestamp) {
            revert Promotion_Expired();
        } 
        // Adjust order number if exceeding max slots
        else if (numParticipants + numOrders > snowball.maxSlots) {
            numOrders = snowball.maxSlots - numParticipants; 
        }

        uint256 newPrice = snowball.cohortPrices[0]; // Set to price of first cohort
        for (uint256 i = 0; i < snowball.thresholds.length; i++) {
            if (numParticipants + numOrders >= snowball.thresholds[i]) {
                newPrice = snowball.cohortPrices[i + 1];
            } else {
                break;
            }
        }

        uint256 minPrice = snowball.cohortPrices[snowball.cohortPrices.length - 1];
        // Calculate commission
        uint256 commissionAmount = (numOrders * minPrice) * commission / 10000;

        // Perform a single transfer for efficiency
        IERC20(erc20Token).transferFrom(msg.sender, address(this), newPrice * numOrders);

        // Update commissions and pay the owner
        earnedCommissions[erc20Token] += commissionAmount;
        uint256 ownerPayment = numOrders * minPrice - commissionAmount;
        IERC20(erc20Token).transfer(promotionsManager.getReceiverAddress(snowball.owner, snowball.erc20Token), ownerPayment);

        uint256 initialReceiptID;
        if (snowball.mintReceipts) {
            // Mint the receipts if required
            initialReceiptID = receiptManager.mintReceipts(msg.sender, snowballID, numParticipants + 1, numOrders);
            
            // Populate the SnowballReceipts and promotionIDToReceiptIDs arrays
            for (uint256 i = 0; i < numOrders; i++) {
                uint256 currentReceiptID = initialReceiptID + i;
                SnowballReceipts[currentReceiptID] = SnowballReceipt({
                    snowballID: snowballID,
                    effectivePricePaid: newPrice
                });

                promotionIDToReceiptIDs[snowballID].push(currentReceiptID); 
            }
        } else {
            // Handle the case when minting is not required
            initialReceiptID = receiptManager.incrementReceiptIDs(numOrders);

            // Only handle unminted receipts
            for (uint256 i = 0; i < numOrders; i++) {
                uint256 currentReceiptID = initialReceiptID + i;
                SnowballReceipts[currentReceiptID] = SnowballReceipt({
                    snowballID: snowballID,
                    effectivePricePaid: newPrice
                });
                promotionIDToReceiptIDs[snowballID].push(currentReceiptID); // Use push to add elements
                // Only map unminted receipts to owners when minting is disabled
                unmintedReceiptsToOwners[currentReceiptID] = msg.sender;
            }
        }

        emit SnowballReceiptsMinted(
            msg.sender, 
            snowballID, 
            numParticipants + 1, 
            initialReceiptID,
            newPrice, 
            numOrders
        );
    }


    function redeemSnowballReceipts(uint256[] calldata receiptIDs) external {
        uint256 redeemableAmount; 
        address erc20Token = Snowballs[SnowballReceipts[receiptIDs[0]].snowballID].erc20Token; //erc20 address of the first token
        for(uint256 i =0; i < receiptIDs.length; i++) {
            SnowballReceipt memory snowballReceipt = SnowballReceipts[receiptIDs[i]];
            Snowball storage snowball = Snowballs[snowballReceipt.snowballID];
            require(erc20Token == snowball.erc20Token, "Invalid"); 
            if(snowball.mintReceipts) {
                require(receiptManager.ownerOf(receiptIDs[i]) == msg.sender, "Not owned");
            }
            else {
                require(unmintedReceiptsToOwners[receiptIDs[i]] == msg.sender, "Not owned");
            }
            uint256 snowballPrice = getSnowballPrice(snowballReceipt.snowballID);
            if (snowballReceipt.effectivePricePaid > snowballPrice) {
                redeemableAmount += (snowballReceipt.effectivePricePaid - snowballPrice);
                SnowballReceipts[receiptIDs[i]].effectivePricePaid = snowballPrice;
                emit SnowballReceiptRedeemed(receiptIDs[i], snowballReceipt.snowballID, snowballReceipt.effectivePricePaid - snowballPrice);
            }
        }
        if(redeemableAmount !=0) {
            IERC20(erc20Token).transfer(
                msg.sender,
                redeemableAmount
            );
        }
    }

    function getSnowballPrice(uint256 snowballID) public view returns(uint256) {
        Snowball storage snowball = Snowballs[snowballID]; 
        uint256 numParticipants = promotionIDToReceiptIDs[snowballID].length;
        console.log(numParticipants);
        if(snowball.maxSlots == numParticipants) {
            /*
            In this case, the price must be that of the last cohort. This specific 
            check method is needed as cancelling a Snowball early sets maxSlots to numParticipants, 
            thus looping through thresholds will not produce the intended result of 
            returning the lowest possible price. 
            */
            return snowball.cohortPrices[snowball.cohortPrices.length-1]; 
        }
        uint256 updatedPrice = snowball.cohortPrices[0]; //Set to price of first cohort
        console.log(updatedPrice);
        uint256 thresholdsLength = snowball.thresholds.length;
        for (uint256 i = 0; i < thresholdsLength; i++) {
            if(numParticipants >= snowball.thresholds[i]) {
                updatedPrice = snowball.cohortPrices[i+1];
                console.log(updatedPrice);
            }
            else{
                console.log(updatedPrice);
                console.log("br");
                break;
            } 
        }
        return updatedPrice; 
    }

    function retrieveExcessSnowballCustody(uint256 snowballID) public {
        Snowball storage snowball = Snowballs[snowballID]; 
        if (!promotionsManager.isApprovedOperator(msg.sender, snowball.owner)) {
            revert NotApproved(); 
        }
        uint256 numParticipants = promotionIDToReceiptIDs[snowballID].length;
        //Check that the snowball has ended
        require((block.timestamp > snowball.endTime || snowball.maxSlots == numParticipants) && !snowball.returnedCustody, "Ineligible");
        // Caculate excess custody
        uint256 excessCustody = calculateExcessSnowballCustody(snowballID);        
        //Return excess if the snowball has ended
        uint256 commissionAmount = excessCustody*commission/10000; //Commission is on all proceeds to sellers. 
        earnedCommissions[snowball.erc20Token] += commissionAmount;
        IERC20(snowball.erc20Token).transfer(promotionsManager.getReceiverAddress(snowball.owner, snowball.erc20Token), excessCustody-commissionAmount); 
        snowball.returnedCustody = true; 
        emit SnowballCustodyRedeemed(snowballID, excessCustody);
    }
    

    function calculateExcessSnowballCustody(uint256 snowballID) public view returns(uint256) {
        Snowball storage snowball = Snowballs[snowballID]; 
        uint256 numParticipants = promotionIDToReceiptIDs[snowballID].length;
        console.log(numParticipants);
        if ((snowball.endTime > block.timestamp && snowball.maxSlots > numParticipants) || snowball.returnedCustody) {
            return 0; 
        }
        uint256 currentPrice = getSnowballPrice(snowballID);
        console.log(currentPrice);
        console.log(snowball.cohortPrices[snowball.cohortPrices.length-1]);
        uint256 excessCustody = (currentPrice-snowball.cohortPrices[snowball.cohortPrices.length-1]) * numParticipants;
        return  excessCustody;
    }

    function setRoyalty(uint256 promotionID, uint256 basisPoints) external override {
        Snowball storage snowball = Snowballs[promotionID]; 
        if (!promotionsManager.isApprovedOperator(msg.sender, snowball.owner)) {
            revert NotApproved(); 
        }
        receiptManager.setRoyalty(promotionID, basisPoints);
    }

    function setPromotionURI(uint256 promotionID, string calldata newURIRoot) external override {
        Snowball storage snowball =Snowballs[promotionID]; 
        if (!promotionsManager.isApprovedOperator(msg.sender, snowball.owner)) {
            revert NotApproved(); 
        }
        if (!snowball.mintReceipts) {
            revert NotCustomURI(); 
        }
        if(bytes(receiptManager.customURIRoot(promotionID)).length != 0) {
            revert URIAlreadSet();
        }
        receiptManager.modifyPromotionURI(promotionID, newURIRoot);
    }

    // Function to get all properties of a Snowball struct, including arrays
    function getSnowball(uint256 snowballID) 
        public 
        view 
        returns (
            uint256 maxSlots,
            uint256 endTime,
            uint256[] memory thresholds,
            uint256[] memory cohortPrices,
            address owner,
            bool returnedCustody,
            address erc20Token,
            bool mintReceipts
        ) 
    {
        Snowball storage snowball = Snowballs[snowballID];
        return (
            snowball.maxSlots,
            snowball.endTime,
            snowball.thresholds,
            snowball.cohortPrices,
            snowball.owner,
            snowball.returnedCustody,
            snowball.erc20Token,
            snowball.mintReceipts
        );
    }

    function cancelSnowball(uint256 snowballID) public {
        Snowball storage snowball =Snowballs[snowballID]; 
        uint256 numParticipants = promotionIDToReceiptIDs[snowballID].length;
        if (!promotionsManager.isApprovedOperator(msg.sender, snowball.owner)) {
            revert NotApproved(); 
        }
        if(snowball.endTime > block.timestamp && numParticipants < snowball.maxSlots) {
            snowball.maxSlots = numParticipants;
            emit SnowballCancelled(snowballID, numParticipants);
        }
    }
}