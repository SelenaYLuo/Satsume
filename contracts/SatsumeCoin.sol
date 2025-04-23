// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";


// error InsufficientBalance();

// contract MyToken is ERC20, Ownable {
//     struct Stake {
//         uint256 startDay;
//         uint256 amount;
//         bool twoYearsLocked; 
//     }

//     address public teamWallet;
//     address public communityAllocation;
//     address public icoAllocation;
//     address public secondaryPlacement;
//     address[] stakersList; 

    

//     bool public icoStarted = false;
//     uint256 public teamWalletUnlockTime;
//     uint256 currentDayCount = 0; 
//     uint256 stakeID = 0; 
//     uint256 public icoEndTime;
//     uint256 public icoPrice; // Price in wei per token
//     uint256 public lockupDays;
//     uint256 stakedWeightedTotal; 

//     mapping(address => uint256) public contributions;
//     mapping(uint256 =>  Stake) public Stakes;
//     mapping(address => uint256) public stakedWeightedTotalMap;
//     mapping(address => uint256[]) public stakesByAddress1yr; 
//     mapping(address => uint256[]) public stakesByAddress2yr; 
//     mapping (address => bool) public staking; 


    


//     constructor(
//         address _teamWallet,
//         address _communityAllocation,
//         address _icoAllocation,
//         address _secondaryPlacement
//     ) ERC20("Satsume", "SUME") Ownable(msg.sender) {
//         teamWallet = _teamWallet;
//         communityAllocation = _communityAllocation;
//         icoAllocation = _icoAllocation;
//         secondaryPlacement = _secondaryPlacement;

//         uint256 totalSupply = 1e24; // Example: 1 million tokens

//         _mint(msg.sender, (totalSupply * 20) / 100); // 20% to msg.sender
//         _mint(teamWallet, (totalSupply * 30) / 100); // 30% to teamWallet
//         _mint(communityAllocation, (totalSupply * 30) / 100); // 30% to communityAllocation
//         _mint(icoAllocation, (totalSupply * 20) / 100); // 20% to ICOAllocation

//         // Set the timelock for teamWallet
//         teamWalletUnlockTime = block.timestamp + 1_000_000 weeks; // Locked until after ICO
//     }

//     modifier onlyAfterTimelock() {
//         require(
//             block.timestamp >= teamWalletUnlockTime,
//             "Timelock not expired"
//         );
//         _;
//     }

//     function setLockupDays(uint256 _lockupDays) external onlyOwner {
//         lockupDays = _lockupDays; 
//     }

//     function startICO(uint256 endTime, uint256 price) external onlyOwner {
//         require(!icoStarted, "ICO already started");
//         require(endTime > block.timestamp, "End time must be in the future");
//         require(price > 0, "Price must be greater than 0");

//         icoStarted = true;
//         icoEndTime = endTime;
//         icoPrice = price;
//         teamWalletUnlockTime = endTime + (lockupDays * 1 days); 
//     }

//     function buyTokens() external payable {
//         require(icoStarted, "ICO has not started");
//         require(block.timestamp <= icoEndTime, "ICO has ended");
//         require(msg.value > 0, "No ETH sent");

//         uint256 amount = msg.value / icoPrice; // Calculate the amount of tokens to buy
//         uint256 availableTokens = balanceOf(icoAllocation);

//         require(amount <= availableTokens, "Not enough tokens available");

//         _transfer(icoAllocation, msg.sender, amount);
//         contributions[msg.sender] += msg.value;
//     }

//     function endICO() external onlyOwner {
//         require(icoStarted, "ICO not started");
//         require(block.timestamp > icoEndTime, "ICO has not ended");

//         icoStarted = false;
//         uint256 remainingTokens = balanceOf(icoAllocation);

//         if (remainingTokens > 0) {
//             _transfer(icoAllocation, secondaryPlacement, remainingTokens);
//         }
//     }

//     function withdraw() external onlyOwner {
//         payable(owner()).transfer(address(this).balance);
//     }

//     function stakeTokens(uint256 _amount, bool twoYears) public {
//         // Ensure that the _amount is greater than 0
//         require(_amount > 0, "Amount must be greater than zero");

//         // Transfer the tokens from the sender to the contract
//         transferFrom(msg.sender, address(this), _amount);

//         // Calculate the weighted amount based on the twoYears flag
//         uint256 weightedAmount;
//         if(twoYears) {
//             weightedAmount = _amount * 3;
//             stakesByAddress2yr[msg.sender].push(stakeID);
//         } 
//         else {
//             weightedAmount = _amount;
//             stakesByAddress1yr[msg.sender].push(stakeID);
//         }

//         // Update the maps for the sender with the weighted amount
//         stakedWeightedTotalMap[msg.sender] += weightedAmount;
//         stakedWeightedTotal += weightedAmount; 

//         Stakes[stakeID] = Stake({
//             startDay: currentDayCount,
//             amount: _amount,
//             twoYearsLocked: twoYears
//         });
//         stakeID+=1; 

//         if (staking[msg.sender] == false) {
//             staking[msg.sender] = true;
//             stakersList.push(msg.sender); 
//         }
//     }

//     function unstakeTokens(uint256 amount) public {
//         uint256[] memory userStakes1yr = stakesByAddress1yr[msg.sender];
        
//         uint256 unstakedAmount = 0;
        
        
//         while(unstakedAmount < amount && i >= 0) {
//             Stake storage stake = Stakes[userStakes1yr[i]]; 
//             if(stake.startDay + 365 * (stake.twoYearsLocked ? 1: 2) < currentDayCount) {
//                 uint256 available = Math.min(stake.amount, amount - unstakedAmount);
//                 unstakedAmount += available;
//                 stake.amount -= available; 
//                 if (stake.amount == 0) {
//                     stakesByAddress1yr[msg.sender].pop();  
//                 }
//                 if(i ==0) {
//                     break;
//                 }
//                 else {
//                     i--; 
//                 }
//             }
//         }

//     }

//     // Override transfer and transferFrom to enforce timelock
//     function _update (
//         address from,
//         address to,
//         uint256 value
//     ) internal virtual override {
//         if (from == teamWallet) {
//             require(
//                 block.timestamp >= teamWalletUnlockTime,
//                 "Team wallet is timelocked"
//             );
//         }
//         super._update(from, to, value);
//     }
// }
