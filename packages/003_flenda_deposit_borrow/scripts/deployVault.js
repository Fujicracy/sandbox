require("dotenv").config();
const hre = require("hardhat");
const fs = require("fs");

const { connextData, aaveV3Data, FlendaDeployments } = require("./const");

if (!process.env.NETWORK) {
  throw "Please set NETWORK in ./packages/hardhat/.env";
}

const CHAIN_NAME = process.env.NETWORK;

const main = async () => {

  // Vault constructor parameters
  const asset = aaveV3Data[CHAIN_NAME].assets.weth;
  const debtAsset = aaveV3Data[CHAIN_NAME].assets.usdc;

  console.log(CHAIN_NAME);
  const Vault = await hre.ethers.getContractFactory("Vault");
  const vault = await Vault.deploy(
    asset,
    debtAsset,
    FlendaDeployments[CHAIN_NAME].oracle,
    {num: 75, denum: 100},
    {num: 80, denum: 100}
  );

  await vault.deployed();
  console.log("Vault deployed to:", vault.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});