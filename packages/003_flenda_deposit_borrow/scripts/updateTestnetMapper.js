require("dotenv").config();
const hre = require("hardhat");
const fs = require("fs");

const { connextData, aaveV3Data, xFujiDeployments } = require("./const");

if (!process.env.NETWORK) {
  throw "Please set NETWORK in ./packages/hardhat/.env";
}

const CHAIN_NAME = process.env.NETWORK;
const TARGET_CHAIN_NAME = 'goerli';

if (CHAIN_NAME == TARGET_CHAIN_NAME) {
  throw "NETWORK in ./packages/hardhat/.env and TARGET_CHAIN_NAME cannot be the same";
}

const main = async () => {

  console.log(CHAIN_NAME);
  const mapper = await hre.ethers.getContractAt("TesnetMapper", xFujiDeployments[CHAIN_NAME].mapper);

  const destDomain = connextData[TARGET_CHAIN_NAME].domainId;

  console.log(`...setting mapping`);
  const originAddrs = [
    aaveV3Data[CHAIN_NAME].assets.weth,
    aaveV3Data[CHAIN_NAME].assets.usdc
  ];
  const destAddrs = [
    aaveV3Data[TARGET_CHAIN_NAME].assets.weth,
    aaveV3Data[TARGET_CHAIN_NAME].assets.usdc
  ];

  let tx = await mapper.setMappings(destDomain, originAddrs, destAddrs)
  await tx.wait()
  console.log(`Mappings set succesful`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});