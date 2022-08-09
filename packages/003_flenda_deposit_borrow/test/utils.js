require("dotenv").config();

if (!process.env.INFURA_ID) {
  throw "Please set INFURA_ID in ./packages/hardhat/.env";
} else if (!process.env.NETWORK) {
  throw "Please set NETWORK in ./packages/hardhat/.env";
} else if (!process.env.PRIVATE_KEY) {
  throw "Please set up PRIVATE_KEY of a test user in ./packages/hardhat/.env\n User must have some tesnet ETH";
}

const provider = new ethers.providers.JsonRpcProvider(`https://${process.env.NETWORK}.infura.io/v3/${process.env.INFURA_ID}`);
let testSigner = new ethers.Wallet(process.env.PRIVATE_KEY);
testSigner = testSigner.connect(provider);

module.exports = {
  testSigner
}