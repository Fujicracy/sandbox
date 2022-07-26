require("dotenv").config();
const hre = require("hardhat");
const fs = require("fs");

const { connextData, aaveV3Data, xFujiDeployments } = require("./const");

if (!process.env.NETWORK) {
  throw "Please set NETWORK in ./packages/hardhat/.env";
}

const CHAIN_NAME = process.env.NETWORK;

const main = async () => {

  console.log(CHAIN_NAME);
  const Mapper = await hre.ethers.getContractFactory("TesnetMapper");
  const mapper = await Mapper.deploy();

  await mapper.deployed();
  console.log(`TesnetMapper deployed to:"`, mapper.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});