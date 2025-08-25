const { ethers, network, deployments } = require("hardhat");
const fs = require("fs");
const { log } = require("console");
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat.config");

const FRONT_END_ADDRESSES_FILE =
  "../satsumeFrontEnd/constants/contractAddresses.json";
const SNOWBALL_MANAGER_ABI_FILE =
  "../satsumeFrontEnd/constants/snowballManagerABI.json";
const DRAWING_MANAGER_ABI_FILE =
  "../satsumeFrontEnd/constants/drawingManagerABI.json";
const SEED_MANAGER_ABI_FILE =
  "../satsumeFrontEnd/constants/seedManagerABI.json";
const RECEIPT_MANAGER_ABI_FILE =
  "../satsumeFrontEnd/constants/receiptManagerABI.json";
const TOKEN_ABI_FILE = "../satsumeFrontEnd/constants/ercTokenABI.json";
const VRF_COORDINATORV2_MOCK_ABI_FILE =
  "../satsumeFrontEnd/constants/VRFCOORDINATORV2MOCKABI.json";
const PROMOTIONS_MANAGER_ABI_FILE =
  "../satsumeFrontEnd/constants/promotionsManagerABI.json";
const MERCHANT_MANAGER_ABI_FILE =
  "../satsumeFrontEnd/constants/merchantManagerABI.json";
const ISO_MANAGER_ABI_FILE = "../satsumeFrontEnd/constants/isoManagerABI.json";
const PROXY_ABI_FILE = "../satsumeFrontEnd/constants/proxyManagerABI.json";

module.exports = async function ({ deployments }) {
  if (process.env.UPDATE_FRONT_END) {
    console.log("Updating front end");
    // await updateContractAddresses();
    // await updateAbi();
    await addApprovedCallersToReceipManager();
    await setDefaultImageURL();
    await addApprovedCallersToISOManager();
    await proxySetUp();
    // await setLoanFactory_WorkingCapProvider();
    //await setSnowballContract();
  }
};

async function updateAbi() {
  // const snowballManager = await deployments.get("SnowballManager");
  const drawingManager = await deployments.get("DrawingManager");
  // const seedManager = await deployments.get("SeedManager");
  const receiptManager = await deployments.get("ReceiptManager");
  const myToken = await deployments.get("MyToken");
  const mock = await deployments.get("VRFCoordinatorV2Mock");
  // const promotionsManager = await deployments.get("PromotionsManager");
  const merchantManager = await deployments.get("MerchantManager");
  const ISOManager = await deployments.get("ISOManager");
  const proxy = await deployments.get("Proxy");

  // Update ABI for Snowball contract
  // fs.writeFileSync(
  //   SNOWBALL_MANAGER_ABI_FILE,
  //   JSON.stringify(snowballManager.interface.fragments, null, 2)
  // );

  // Update ABI for drawing manager contract
  // fs.writeFileSync(
  //   SEED_MANAGER_ABI_FILE,
  //   JSON.stringify(seedManager.interface.fragments, null, 2)
  // );

  // Update ABI for drawing manager contract
  // fs.writeFileSync(
  //   DRAWING_MANAGER_ABI_FILE,
  //   JSON.stringify(drawingManager.interface.fragments, null, 2)
  // );
  console.log("3");
  fs.writeFileSync(
    PROXY_ABI_FILE,
    JSON.stringify(proxy.interface.fragments, null, 2)
  );
  fs.writeFileSync(
    MERCHANT_MANAGER_ABI_FILE,
    JSON.stringify(merchantManager.interface.fragments, null, 2)
  );
  fs.writeFileSync(
    ISO_MANAGER_ABI_FILE,
    JSON.stringify(ISOManager.interface.fragments, null, 2)
  );
  // Update ABI for SnowballWorkingCapital contract
  fs.writeFileSync(
    RECEIPT_MANAGER_ABI_FILE,
    JSON.stringify(receiptManager.interface.fragments, null, 2)
  );

  // Update ABI for MyToken contract
  fs.writeFileSync(
    TOKEN_ABI_FILE,
    JSON.stringify(myToken.interface.fragments, null, 2)
  );

  // Update ABI for MyToken contract
  fs.writeFileSync(
    VRF_COORDINATORV2_MOCK_ABI_FILE,
    JSON.stringify(mock.interface.fragments, null, 2)
  );

  // Update ABI for PromotionsManager contract
  // fs.writeFileSync(
  //   PROMOTIONS_MANAGER_ABI_FILE,
  //   JSON.stringify(promotionsManager.interface.fragments, null, 2)
  // );
}

async function updateContractAddresses() {
  // const snowballManager = await deployments.get("SnowballManager");
  const drawingManager = await deployments.get("DrawingManager");
  // const seedManager = await deployments.get("SeedManager");
  const receiptManager = await deployments.get("ReceiptManager");
  const myToken = await deployments.get("MyToken");
  const mock = await deployments.get("VRFCoordinatorV2Mock");
  // const promotionsManager = await deployments.get("PromotionsManager");
  const merchantManager = await deployments.get("MerchantManager");
  const ISOManager = await deployments.get("ISOManager");
  const proxy = await deployments.get("Proxy");

  const chainId = network.config.chainId.toString();

  let addresses = {};

  // Try reading existing addresses file
  try {
    addresses = JSON.parse(fs.readFileSync(FRONT_END_ADDRESSES_FILE));
  } catch (err) {
    console.log("No existing addresses file found. Creating a new one.");
  }

  // Update or create the new addresses for the current network
  addresses[chainId] = {
    // snowballManager: [snowballManager.address],
    // seedManager: [seedManager.address],
    drawingManager: [drawingManager.address],
    receiptManager: [receiptManager.address],
    MyToken: [myToken.address],
    VRFMock: [mock.address],
    merchantManager: [merchantManager.address],
    isoManager: [isoManager.address],
    proxy: [proxy.address],
    // promotionsManager: [promotionsManager.address],
  };

  fs.writeFileSync(
    FRONT_END_ADDRESSES_FILE,
    JSON.stringify(addresses, null, 2)
  );
}

// async function approveERC20TokenPromoManager() {
//   const snowballManager = await ethers.getContract("SnowballManager");
//   const ercToken = await deployments.get("MyToken");

//   console.log(`Approving receipt manager for my ERCToken on promo Manager`);
//   const tx = await snowballManager.approveERC20Token(ercToken.address);
//   await tx.wait(); // Wait for the transaction to be mined
//   console.log("Token approved");
// }

// async function approveERC20TokenDrawingManager() {
//   const drawingManager = await ethers.getContract("DrawingManager");
//   const ercToken = await deployments.get("MyToken");

//   console.log(`Approving receipt manager for my ERCToken on drawing manager`);
//   const tx = await drawingManager.approveERC20Token(ercToken.address);
//   await tx.wait(); // Wait for the transaction to be mined
//   console.log("Token approved");
// }

async function addApprovedCallersToReceipManager() {
  const receiptManager = await ethers.getContract("ReceiptManager");
  const drawingManager = await deployments.get("DrawingManager");
  // const snowballManager = await deployments.get("SnowballManager");
  // const seedManager = await deployments.get("SeedManager");

  console.log(`Adding drawing manager as approved to receipt  manager`);
  const tx2 = await receiptManager.addApprovedCaller(drawingManager.address);
  await tx2.wait(); // Wait for the transaction to be mined
  console.log("Approved");

  // console.log(`Adding drawing manager as approved to receipt  manager`);
  // const tx3 = await receiptManager.addApprovedCaller(seedManager.address);
  // await tx3.wait(); // Wait for the transaction to be mined
  // console.log("Approved");
}

async function addApprovedCallersToISOManager() {
  console.log("Calling ISO Manager");
  const isoManager = await ethers.getContract("ISOManager");
  const drawingManager = await deployments.get("DrawingManager");
  // const snowballManager = await deployments.get("SnowballManager");
  // const seedManager = await deployments.get("SeedManager");

  console.log(`Adding drawing manager as approved to iso  manager`);
  const tx2 = await isoManager.addApprovedCaller(drawingManager.address);
  await tx2.wait(); // Wait for the transaction to be mined
  console.log("Approved");

  // console.log(`Adding drawing manager as approved to receipt  manager`);
  // const tx3 = await receiptManager.addApprovedCaller(seedManager.address);
  // await tx3.wait(); // Wait for the transaction to be mined
  // console.log("Approved");
}

async function proxySetUp() {
  console.log("Adding drawing manager to proxy");
  const proxy = await ethers.getContract("Proxy");
  const drawingManager = await deployments.get("DrawingManager");
  // const snowballManager = await deployments.get("SnowballManager");
  // const seedManager = await deployments.get("SeedManager");

  console.log(`Adding drawing manager as approved toproxy`);
  const tx2 = await proxy.approvePromotions(1, drawingManager.address);
  await tx2.wait(); // Wait for the transaction to be mined
  console.log("Approved");

  // console.log(`Adding drawing manager as approved to receipt  manager`);
  // const tx3 = await receiptManager.addApprovedCaller(seedManager.address);
  // await tx3.wait(); // Wait for the transaction to be mined
  // console.log("Approved");
}

async function setDefaultImageURL() {
  const receiptManager = await ethers.getContract("ReceiptManager");
  const URL =
    "https://ipfs.io/ipfs/QmWx8A8QUkjgaQ52g4hmTjtHTGYwS9kdyR2MJH3LouW21U";

  console.log(`Updating default NFT image ${URL}`);
  const tx = await receiptManager.setDefaultURIRoot(URL);
  await tx.wait(); // Wait for the transaction to be mined
  console.log("NFT image updated");
}

// async function setLoanFactory_WorkingCapProvider() {
//   const snowballWorkingCapital = await ethers.getContract(
//     "SnowballWorkingCapital"
//   );
//   const loanFactory = await deployments.get("LoanFactory");

//   console.log(
//     `Setting Loan Factory for the Working Capital Provider ${loanFactory.address}`
//   );
//   const tx = await snowballWorkingCapital.setLoanFactory(loanFactory.address);
//   await tx.wait(); // Wait for the transaction to be mined
//   console.log("Loan Factory set successfully for the Working Capital Provider");
// }

// async function setSnowballContract() {
//   const snowball = await deployments.get("Snowball");
//   const snowballWorkingCapital = await ethers.getContract(
//     "SnowballWorkingCapital"
//   );

//   console.log(`Setting Snowball Contract to ${snowball.address}`);
//   const tx = await snowballWorkingCapital.setSnowballContract(snowball.address);
//   await tx.wait(); // Wait for the transaction to be mined
//   console.log("Snowball Contract set successfully");
// }

module.exports.tags = ["all", "frontend"];
