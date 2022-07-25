require("dotenv").config();
const fs = require("fs");

require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-contract-sizer");

if (!process.env.INFURA_ID) {
  throw "Please set INFURA_ID in ./packages/hardhat/.env";
}
const defaultNetwork = "localhost";

function mnemonic() {
  try {
    return fs.readFileSync("./mnemonic.txt").toString().trim();
  } catch (e) {
    if (defaultNetwork !== "localhost") {
      console.log(
        "☢️ WARNING: No mnemonic file created for a deploy account. Try `yarn run generate` and then `yarn run account`."
      );
    }
  }
  return "";
}

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.9",
  defaultNetwork,
  networks: {
    localhost: {
      url: "http://localhost:8545",
      timeout: 200000,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : { mnemonic: mnemonic() },
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : { mnemonic: mnemonic() },
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_ID}`,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : { mnemonic: mnemonic() },
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_KEY
  }
};

task("generate", "Create a wallet for builder deploys", async (_, { ethers }) => {
  const newWallet = ethers.Wallet.createRandom();
  const address = newWallet.address;
  const mnemonic = newWallet.mnemonic.phrase
  console.log("🔐 Account Generated as " + address + " and set as mnemonic in packages/hardhat");
  fs.writeFileSync("./" + address + ".txt", `${address}\n${mnemonic.toString()}\n${newWallet.privateKey}`);
  fs.writeFileSync("./mnemonic.txt", mnemonic.toString());
});
