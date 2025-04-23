// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "hardhat/console.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

// contract ReceiptManager is ERC721, ERC721Enumerable {
//     struct EquityOffering {
//         address offeror;
//         uint256 equitySharePercentage;
//         uint256 pricePerShare;
//         uint256 sharesOffered;
//         uint256 sharesSold;
//         uint256 redeemableAmount;
//         address erc20TokenAddress; //this is the token that the payment amount is specified in
//     }

//     struct TokenStatus {
//         uint256 redeemedAmount;
//         uint256 offeringRound;
//     }

//     uint256 numOffers; //Also serves as offering ID and is incremented when creating offerings
//     address[] acceptableStablecoins; //basiclally should be usdc, usdt, and dai.
//     mapping(uint256 => EquityOffering) equityOfferings;
//     mapping(uint256 => TokenStatus) tokenStatuses;
//     mapping(address => uint256[]) addressToListOfOfferings;
//     mapping(address => uint256) totalSharesOffered;

//     constructor(address _promotionManagerAddress) ERC721("Something", "TTT") {}

//     //The next three functions are necessary overrides for ERC721 Enumerable
//     function _update(
//         address to,
//         uint256 tokenId,
//         address auth
//     ) internal override(ERC721, ERC721Enumerable) returns (address) {
//         return super._update(to, tokenId, auth);
//     }

//     function _increaseBalance(
//         address account,
//         uint128 value
//     ) internal override(ERC721, ERC721Enumerable) {
//         super._increaseBalance(account, value);
//     }

//     function supportsInterface(
//         bytes4 interfaceId
//     ) public view override(ERC721, ERC721Enumerable) returns (bool) {
//         return super.supportsInterface(interfaceId);
//     }

//     //Start Here!
//     function createOffering() external {
//         //Allows a user to create an offering, and add the offering to the appropriate mappings.
//         //Include appropriate checks like that equitySharePercentage is under 100%.
//         //call eligibleOffering() to check if the seller can create a new round of offers
//     }

//     function eligibleOffering() internal returns (bool) {
//         //Check that for the latest round, all of the offered shares have been sold and that the redeemable amount is greater than the price pershare.
//     }

//     function joinOffering(uint256 offer) public {
//         //Check that offering is still valid.
//         //make payment to the offeror
//         //mint the share of the offeror
//         //update the token status
//         _mint(msg.sender, totalSupply() + 1);
//     }

//     // function mint(address to, uint256 tokenID) internal {

//     //     _mint(msg.sender, tokenID);
//     // }

//     //Our other contracts will call this function. 消费者下单100USDC，我们其他平台会call这个function，确认一下卖家没有发过offering。如果没有offering，就直接把100转给卖家，如果有offering，得先向NFT持有者发红。
//     function receiveAmount(
//         address seller,
//         uint256 receivedAmount,
//         address erc20TokenType
//     ) external {
//         if (addressToListOfOfferings[seller].length == 0) {
//             //pay directly
//         } else {
//             //change state of the offerings (redeemableAmount). Start from the latest offering addressToListOfOfferings[seller][addressToListOfOfferings[seller].length-1]
//         }
//     }

//     function redeemToken(uint256 tokenID) external {
//         //calculate tthe redeemable amount based on what has already been redeemed and the round of the offering.
//         //send the amount to msg.sender
//     }

//     //function to add acceptable stablecoins to the state array
//     function addStableCoin(address newStablecoin) external onlyOwner {
//         acceptableStablecoins.push(newStablecoin);
//     }
// }
