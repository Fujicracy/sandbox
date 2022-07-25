require("dotenv").config();
const hre = require("hardhat");
const fs = require("fs");

const { connextData, aaveV3Data, FlendaDeployments } = require("./const");

if (!process.env.NETWORK) {
  throw "Please set NETWORK in ./packages/hardhat/.env";
}

const CHAIN_NAME = process.env.NETWORK;

const main = async () => {

  const contractName = `AaveV3${CHAIN_NAME[0].toUpperCase()}${CHAIN_NAME.slice(1)}`

  console.log(CHAIN_NAME);
  const AaveV3 = await hre.ethers.getContractFactory(contractName);
  const aaveV3 = await AaveV3.deploy();

  await aaveV3.deployed();
  console.log(`${contractName} deployed to:"`, aaveV3.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});