// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface for Promotion Contracts
interface IPromotion {
    function joinPromotion(
        uint256 promotionID,
        uint256 purchaseAmount,
        uint256 orderID,
        address buyer
    ) external;
}

contract Proxy is ReentrancyGuard, EIP712 {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    address public contractOwner;
    mapping(address => mapping(address => bool)) public approvedOperators;
    mapping(address => address[]) public arrayOfApprovedOperators;
    mapping(address => mapping(address => bool)) public approvedAdministrators;
    mapping(address => address[]) public arrayOfApprovedAdministrators;
    mapping(address => mapping(address => address)) public receiverAccounts;
    uint256[] public initialPromotionIDs; //sorted list
    address[] public approvedPromotions;

    /// @notice SKU state struct
    struct SkuState {
        uint256 price; // Unit price
        uint256 priceVersion; // Price version
        uint256 inventory; // Available stock
        uint256 inventoryVersion; // Inventory version
    }

    /// @notice Struct for a purchase item
    struct PurchaseItem {
        uint256 skuId; // SKU ID
        uint256 quantity; // Quantity to buy
        uint256 unitPrice; // Price per unit
        address priceToken; // Payment token address (ETH = address(0))
        uint256 priceVersion; // Price version
        uint256 inventory; // current version of inventory
        uint256 inventoryVersion; // Inventory version
        uint256 promotionID; // Receiver of the payment
    }

    bytes32 private constant PURCHASE_ITEM_TYPEHASH =
        keccak256(
            "PurchaseItem(uint256 skuId,uint256 quantity,uint256 unitPrice,address priceToken,uint256 priceVersion,uint256 inventory,uint256 inventoryVersion,uint256 promotionID)"
        );

    /// @notice SKU mapping
    mapping(uint256 => SkuState) public skus;

    /// @notice Used order numbers to prevent replay attacks
    mapping(uint256 => bool) public usedOrderNo;

    /// @notice Used struct hashes to prevent signature replay
    mapping(bytes32 => bool) public usedHashes;

    /// @notice System signer address for EIP-712 signatures
    address public systemSigner;

    /// @notice Event emitted on a purchase
    event Purchased(
        address indexed buyer,
        uint256 indexed orderNo,
        PurchaseItem[] items
    );

    /// @notice Event emitted when a SKU is updated
    event SkuUpdated(
        uint256 indexed skuId,
        uint256 newPrice,
        uint256 priceVersion,
        uint256 newInventory,
        uint256 inventoryVersion
    );

    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Not Owner");
        _;
    }

    /// @param _signer The authorized system signer
    constructor(address _signer) EIP712("Shop", "1") {
        require(_signer != address(0), "invalid signer");
        systemSigner = _signer;
        contractOwner = msg.sender;
    }

    function setOwner(address newOwner) public onlyOwner {
        contractOwner = newOwner;
    }

    function setSystemSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "invalid signer");
        systemSigner = _signer;
    }

    function getAllApprovedPromotions()
        external
        view
        returns (address[] memory)
    {
        return approvedPromotions;
    }

    /// @notice Batch purchase using a single EIP-712 signature
    /// @param items Array of purchase items
    /// @param payExpire Expiration timestamp for payment
    /// @param orderNo Unique order number to prevent replay
    /// @param signature EIP-712 signature from system signer
    function buyWithBatchHash(
        PurchaseItem[] calldata items,
        uint256 payExpire,
        uint256 orderNo,
        // address[] calldata tokenAddresses,
        // uint256[] calldata permittedAmounts,
        // //permitted  signatures
        bytes calldata signature
    ) external payable nonReentrant {
        require(block.timestamp <= payExpire, "expired");
        require(items.length > 0, "empty batch");
        require(!usedOrderNo[orderNo], "orderNo used");

        // 1. Hash the entire PurchaseItem array
        bytes32 itemsHash = hashPurchaseItems(items);

        // 2. Construct the EIP-712 struct hash and verify signature
        //这里需要添加 promotionIDs + numOrders 吗
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "BatchPurchase(uint256 payExpire,uint256 orderNo,address buyer,bytes32 itemsHash)"
                ),
                payExpire,
                orderNo,
                msg.sender,
                itemsHash
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);
        require(
            ECDSA.recover(digest, signature) == systemSigner,
            "invalid signature"
        );

        // 3. Process each purchase item
        for (uint256 i = 0; i < items.length; i++) {
            PurchaseItem calldata item = items[i];

            SkuState storage s = skus[item.skuId];

            // Update price if submitted version is newer
            require(item.priceVersion >= s.priceVersion, "stale price");
            if (item.priceVersion > s.priceVersion) {
                s.price = item.unitPrice;
                s.priceVersion = item.priceVersion;
            } else {
                require(s.price == item.unitPrice, "price mismatch");
            }

            // Update inventory if submitted version is newer
            require(
                item.inventoryVersion >= s.inventoryVersion,
                "stale inventory"
            );
            require(s.inventory >= item.quantity, "insufficient stock");
            if (item.inventoryVersion > s.inventoryVersion) {
                s.inventory = item.inventory - item.quantity;
                s.inventoryVersion = item.inventoryVersion;
            }

            if (item.promotionID < initialPromotionIDs[0]) {
                revert("Invalid promotion ID");
            }

            // Start from the last promotion and work backwards
            uint256 index = initialPromotionIDs.length - 1;

            // Find the largest initial ID <= promotionID
            while (index > 0 && initialPromotionIDs[index] > item.promotionID) {
                unchecked {
                    index--;
                }
            }

            address promotionContract = approvedPromotions[index];
            IPromotion(promotionContract).joinPromotion(
                item.promotionID,
                s.price,
                orderNo,
                msg.sender
            );
        }

        // 5. Mark order number as used to prevent replay
        usedOrderNo[orderNo] = true;
        // Emit Purchased event
        emit Purchased(msg.sender, orderNo, items);
    }

    /// @notice Constructs a hash for an array of PurchaseItem structs
    /// @param items Array of PurchaseItem structs
    /// @return bytes32 The cumulative hash of all items
    function hashPurchaseItems(
        PurchaseItem[] calldata items
    ) public pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            hashes[i] = _hashPurchaseItem(items[i]);
        }
        //EIP-712
        return keccak256(abi.encodePacked(hashes));
    }

    function _hashPurchaseItem(
        PurchaseItem calldata item
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PURCHASE_ITEM_TYPEHASH,
                    item.skuId,
                    item.quantity,
                    item.unitPrice,
                    item.priceToken,
                    item.priceVersion,
                    item.inventory,
                    item.inventoryVersion,
                    item.promotionID
                )
            );
    }

    /// @notice Update SKU using a system signature
    /// @param skuId SKU ID
    /// @param newPrice New unit price
    /// @param priceVersion Price version
    /// @param newInventory New inventory amount
    /// @param inventoryVersion Inventory version
    /// @param expireTime Signature expiration timestamp
    /// @param updater Address authorized to perform the update
    /// @param signature EIP-712 signature from system signer
    function updateSkuWithSig(
        uint256 skuId,
        uint256 newPrice,
        uint256 priceVersion,
        uint256 newInventory,
        uint256 inventoryVersion,
        uint256 expireTime,
        address updater,
        bytes calldata signature
    ) external {
        require(msg.sender == updater, "caller not authorized");
        require(block.timestamp <= expireTime, "signature expired");

        // Construct EIP-712 struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "UpdateSku(uint256 skuId,uint256 newPrice,uint256 priceVersion,uint256 newInventory,uint256 inventoryVersion,uint256 expireTime,address updater)"
                ),
                skuId,
                newPrice,
                priceVersion,
                newInventory,
                inventoryVersion,
                expireTime,
                updater
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);

        // Verify signature and prevent replay
        require(
            ECDSA.recover(digest, signature) == systemSigner,
            "invalid signature"
        );
        require(!usedHashes[digest], "signature replayed");
        usedHashes[digest] = true;

        SkuState storage s = skus[skuId];
        require(priceVersion >= s.priceVersion, "stale price version");
        require(
            inventoryVersion >= s.inventoryVersion,
            "stale inventory version"
        );

        // Update SKU
        if (priceVersion > s.priceVersion) {
            s.price = newPrice;
            s.priceVersion = priceVersion;
        }

        if (inventoryVersion > s.inventoryVersion) {
            s.inventory = newInventory;
            s.inventoryVersion = inventoryVersion;
        }

        // Emit SKU update event
        emit SkuUpdated(
            skuId,
            s.price,
            s.priceVersion,
            s.inventory,
            s.inventoryVersion
        );
    }

    /// @notice Get SKU state
    /// @param skuId SKU ID
    /// @return SkuState struct containing price, inventory, and version info
    function getSku(uint256 skuId) external view returns (SkuState memory) {
        return skus[skuId];
    }

    function approvePromotions(
        uint256 _initialID,
        address _promotionAddress
    ) public onlyOwner {
        uint256[] storage initialIDs = initialPromotionIDs;
        address[] storage promotions = approvedPromotions;
        uint256 length = initialIDs.length;

        // Check for duplicate ID
        for (uint256 i = 0; i < length; ) {
            if (initialIDs[i] == _initialID) {
                revert("Duplicate promotion ID");
            }
            unchecked {
                ++i;
            }
        }

        // Find insertion position (maintain ascending order)
        uint256 insertIndex = length;
        for (uint256 i = 0; i < length; ) {
            if (initialIDs[i] > _initialID) {
                insertIndex = i;
                break;
            }
            unchecked {
                ++i;
            }
        }

        // Expand arrays with dummy values
        initialIDs.push(0);
        promotions.push(address(0));

        // Shift elements after insertion point
        for (uint256 i = length; i > insertIndex; ) {
            unchecked {
                initialIDs[i] = initialIDs[i - 1];
                promotions[i] = promotions[i - 1];
                --i;
            }
        }

        // Insert new values
        initialIDs[insertIndex] = _initialID;
        promotions[insertIndex] = _promotionAddress;
    }
}
