require("dotenv").config();
const hre = require("hardhat");
const fs = require("fs");

const { aaveV3Data, mockOracleData } = require("./const");

if (!process.env.NETWORK) {
  throw "Please set NETWORK in ./packages/hardhat/.env";
} else if (process.env.NETWORK != hre.ethers.provider.network.name) {
  throw "Check NETWORK in ./packages/hardhat/.env and invoked `--network name` in command match";
}

const CHAIN_NAME = process.env.NETWORK;

const main = async () => {

  // FujiOralce constructor parameters
  const assetsAddrs = [aaveV3Data[CHAIN_NAME].assets.weth, aaveV3Data[CHAIN_NAME].assets.usdc];
  const priceFeedsAddrs = [mockOracleData[CHAIN_NAME].weth, mockOracleData[CHAIN_NAME].usdc];

  console.log(CHAIN_NAME);
  console.log("...deploying FujiOracle");
  const FujiOracle = await hre.ethers.getContractFactory("FujiOracle");
  const oracle = await FujiOracle.deploy(
    assetsAddrs,
    priceFeedsAddrs,
  );

  await oracle.deployed();
  console.log("FujiOracle deployed to:", oracle.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});