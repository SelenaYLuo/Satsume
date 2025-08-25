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

  receiptManager = await deployments.get("ReceiptManager");
  receiptManagerAddress = receiptManager.address;
  merchantManager = await deployments.get("MerchantManager");
  merchantManagerAddress = merchantManager.address;
  isoManager = await deployments.get("ISOManager");
  isoManagerAddress = isoManager.address;

  const gasLane = networkConfig[chainId]["gasLane"];
  const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"];
  let vrfCoordinatorV2Address, subscriptionId;
  if (developmentChains.includes(network.name)) {
    const vrfCoordinatorV2Mock = await ethers.getContract(
      "VRFCoordinatorV2Mock"
    );
    vrfCoordinatorv2Deployment = await deployments.get("VRFCoordinatorV2Mock");
    vrfCoordinatorV2Address = vrfCoordinatorv2Deployment.address;
    receiptManagerDeployment = await deployments.get("ReceiptManager");
    receiptManagerAddress = receiptManagerDeployment.address;
    const transactionResponse = await vrfCoordinatorV2Mock.createSubscription();
    const transactionReceipt = await transactionResponse.wait(1);
    console.log(transactionReceipt);
    subscriptionId = transactionReceipt.logs[0].topics[1]; //transactionReceipt.events[0].args.subId;
    console.log(transactionReceipt.logs);
    await vrfCoordinatorV2Mock.fundSubscription(
      subscriptionId,
      VRF_SUB_FUND_AMOUNT
    );
  } else {
    vrfCoordinatorV2Address = networkConfig[chainId]["VRFCoordinatorV2Mock"];
    subscriptionId = networkConfig[chainId]["subscriptionId"];
  }
  const args = [
    vrfCoordinatorV2Address,
    receiptManagerAddress,
    merchantManagerAddress,
    isoManagerAddress,
    gasLane,
    subscriptionId,
    callbackGasLimit,
  ];
  log("Deploying Drawing Manager");
  const drawingManager = await deploy("DrawingManager", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  log("Adding drawing contract as VRF Consumer");
  if (developmentChains.includes(network.name)) {
    drawingManagerDeployment = await deployments.get("DrawingManager");
    const vrfCoordinatorV2Mock = await ethers.getContract(
      "VRFCoordinatorV2Mock"
    );
    await vrfCoordinatorV2Mock.addConsumer(
      subscriptionId,
      drawingManagerDeployment.address
    );
  }
};
