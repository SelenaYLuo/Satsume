const { network, ethers } = require("hardhat");
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat.config");
const { verify } = require("../helper-hardhat.config");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;
  // log("working");
  // // Get the deployed token address
  // const promotionManagerAddress = await deployments.get("PromotionManager");
  receiptManager = await deployments.get("ReceiptManager");
  receiptManagerAddress = receiptManager.address;
  promotionsManager = await deployments.get("PromotionsManager");
  promotionsManagerAddress = promotionsManager.address;

  log("Deploying Snowball Manager");

  const promotionManager = await deploy("SnowballManager", {
    from: deployer,
    args: [receiptManagerAddress, promotionsManagerAddress],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
};
