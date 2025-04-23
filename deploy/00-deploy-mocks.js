const { network, ethers } = require("hardhat")
const { developmentChains } = require("../helper-hardhat.config.js")

const BASE_FEE = ethers.parseEther(".25") //Link premium
const GAS_PRICE_LINK = 1e9 //LINK PER GAS
const args = [BASE_FEE, GAS_PRICE_LINK]

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    if (developmentChains.includes(network.name)) {
        log("local network detected, deploying mocks")
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        log("Mocks deployed")
        log("---------------------------------------------")
    }
}

module.exports.tags = ["all", "mocks"]
