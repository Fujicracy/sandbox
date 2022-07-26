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
  const Router = await hre.ethers.getContractFactory("Router");
  const router = await Router.deploy(
    connextData[CHAIN_NAME].ConnextHandler.address,
    connextData[CHAIN_NAME].PromiseRouter.address,
    connextData[CHAIN_NAME].TestToken.address,
    xFujiDeployments[CHAIN_NAME].vault,
    xFujiDeployments[CHAIN_NAME].mapper
  );

  await router.deployed();
  console.log(`router deployed to:"`, router.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});