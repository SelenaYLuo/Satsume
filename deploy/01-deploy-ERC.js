const { network, ethers } = require("hardhat");
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat.config");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  // Deploy the ERC20 token using the deployer account
  const token = await deploy("MyToken", {
    from: deployer,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  log("Deployed token at address:", token.address);

  // Get the deployed contract instance using the deployer account
  const tokenContract = await ethers.getContractAt("MyToken", token.address);

  // Get the list of Hardhat accounts
  const accounts = await ethers.getSigners();

  // Amount to transfer to each account (e.g., 100 tokens)
  const amount = 10000 * 10 ** 6;
  const tx1 = await tokenContract.transfer(
    "0x4697F1779CD916fB59C605f672D263e38CCb75bA",
    amount
  );
  console.log(tx1);
  const tx2 = await tokenContract.transfer(
    "0x457988C456Ba8BE1E60841AFd7ddEB2238AE1458",
    amount
  );
  const tx3 = await tokenContract.transfer(
    "0x89E2092747bFE00B2ED9ea748dfb2bFAA784A680",
    amount
  );
  const tx4 = await tokenContract.transfer(
    "0x585a05219Ed1d9d5DD88c3bf0FA6f7c03536307A",
    amount
  );

  // Transfer tokens to each account from the deployer account
  for (const account of accounts) {
    const tx = await tokenContract.transfer(account.address, amount);
    await tx.wait();
    log(`Transferred 10000 tokens to ${account.address}`);
  }

  // Transfer ETH to each of the specified addresses
  if (developmentChains.includes(network.name)) {
    const ethAmount = ethers.parseEther("5"); // 5 ETH in wei (ethers.js v6 syntax)
    const recipientAddresses = [
      "0x4697F1779CD916fB59C605f672D263e38CCb75bA",
      "0x457988C456Ba8BE1E60841AFd7ddEB2238AE1458",
      "0x89E2092747bFE00B2ED9ea748dfb2bFAA784A680",
      "0x585a05219Ed1d9d5DD88c3bf0FA6f7c03536307A",
    ];

    for (const address of recipientAddresses) {
      const tx = await accounts[0].sendTransaction({
        to: address,
        value: ethAmount,
      });
      await tx.wait();
      log(`Transferred 5 ETH from ${accounts[0].address} to ${address}`);
    }
  }
};

module.exports.tags = ["all", "token"];
