const { network, ethers } = require("hardhat");
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat.config");
const { verify } = require("../helper-hardhat.config");
const VRF_SUB_FUND_AMOUNT = ethers.parseEther("20");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  log("Deploying Merchant Manager");
  const args = [];
  const ReceiptManager = await deploy("MerchantManager", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  if (developmentChains.includes(network.name)) {
    MerchantManager = await deployments.get("MerchantManager");
  }

  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Verifying...");
    await verify(MerchantManager.address, args);
  }
  log("--------------------------------------------------------");
};
