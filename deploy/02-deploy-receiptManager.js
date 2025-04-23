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

  // log("Deply the receipt manager");
  // // Get the deployed token address
  // const tokenAddress = await deployments.get("MyToken");
  // const gasLane = networkConfig[chainId]["gasLane"];
  // const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"];
  // let vrfCoordinatorV2Address, subscriptionId;

  // if (developmentChains.includes(network.name)) {
  //   const vrfCoordinatorV2Mock = await ethers.getContract(
  //     "VRFCoordinatorV2Mock"
  //   );
  //   vrfCoordinatorv2Deployment = await deployments.get("VRFCoordinatorV2Mock");

  //   vrfCoordinatorV2Address = vrfCoordinatorv2Deployment.address;
  //   const transactionResponse = await vrfCoordinatorV2Mock.createSubscription();
  //   const transactionReceipt = await transactionResponse.wait(1);
  //   console.log(transactionReceipt);
  //   subscriptionId = transactionReceipt.logs[0].topics[1]; //transactionReceipt.events[0].args.subId;
  //   console.log(transactionReceipt.logs);
  //   await vrfCoordinatorV2Mock.fundSubscription(
  //     subscriptionId,
  //     VRF_SUB_FUND_AMOUNT
  //   );
  // } else {
  //   vrfCoordinatorV2Address = networkConfig[chainId]["VRFCoordinatorV2Mock"];
  //   subscriptionId = networkConfig[chainId]["subscriptionId"];
  // }
  // const args = [];
  // //[
  // //   vrfCoordinatorV2Address,
  // //   gasLane,
  // //   subscriptionId,
  // //   callbackGasLimit,
  // // ];

  log("Deploying Receipt Manager");
  const args = [];
  const ReceiptManager = await deploy("ReceiptManager", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  if (developmentChains.includes(network.name)) {
    receiptManager = await deployments.get("ReceiptManager");
  }

  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Verifying...");
    await verify(ReceiptManager.address, args);
  }
  log("--------------------------------------------------------");
};

// const { network, ethers } = require("hardhat");
// const {
//   developmentChains,
//   networkConfig,
// } = require("../helper-hardhat.config");
// const { verify } = require("../helper-hardhat.config");

// const VRF_SUB_FUND_AMOUNT = ethers.parseEther("2");

// module.exports = async function ({ getNamedAccounts, deployments }) {
//   const { deploy, log } = deployments;
//   const { deployer } = await getNamedAccounts();
//   const chainId = network.config.chainId;
//   let vrfCoordinatorV2Address, subscriptionId;

//   if (developmentChains.includes(network.name)) {
//     const vrfCoordinatorV2Mock = await ethers.getContractAt(
//       "VRFCoordinatorV2Mock",
//       deployer
//     );
//     //log("vrfCoordinatorV2Mock")
//     log(vrfCoordinatorV2Mock);
//     vrfCoordinatorV2Address = vrfCoordinatorV2Mock.target;
//     const transactionResponse = await vrfCoordinatorV2Mock.createSubscription();
//     const transactionReceipt = await transactionResponse.wait(1);
//     //log(transactionReceipt)
//     subscriptionId = 1; // transactionReceipt.logs[0].args[0]
//     await vrfCoordinatorV2Mock.fundSubscription(
//       subscriptionId,
//       VRF_SUB_FUND_AMOUNT
//     );
//   } else {
//     vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"];
//     subscriptionId = networkConfig[chainId]["subscriptionId"];
//   }
//   const entranceFee = networkConfig[chainId]["entranceFee"];
//   const gasLane = networkConfig[chainId]["gasLane"];
//   const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"];
//   const interval = networkConfig[chainId]["interval"];

//   const args = [
//     vrfCoordinatorV2Address,
//     gasLane,
//     subscriptionId,
//     callbackGasLimit,
//     interval,
//   ];
//   const Snowball = await deploy("Snowball", {
//     from: deployer,
//     args: args,
//     log: true,
//     waitConfirmations: network.config.blockConfirmations || 1,
//   });

//   if (
//     !developmentChains.includes(network.name) &&
//     process.env.ETHERSCAN_API_KEY
//   ) {
//     log("Verifying...");
//     await verify(raffle.address, args);
//   }
//   log("--------------------------------------------------------");
// };

// module.exports.tags = ["all", "snowball"];
