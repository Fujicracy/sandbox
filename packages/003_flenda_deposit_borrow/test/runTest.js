require("dotenv").config();
const { ethers } = require("hardhat");
const { connextData, xFujiDeployments } = require("../scripts/const");
const { testSigner } = require("./utils.js");

if (!process.env.INFURA_ID) {
  throw "Please set INFURA_ID in .env";
} else if (!process.env.NETWORK) {
  throw "Please set NETWORK in .env";
} else if (!process.env.PRIVATE_KEY) {
  throw "Please set up PRIVATE_KEY for a test user in .env";
}

const ORIGIN_CHAIN = process.env.NETWORK;

/// Test Parameters ///
const DEST_CHAIN = 'rinkeby'; // Set up the destination chain
const DEPOSIT_AMOUNT = ethers.utils.parseEther("0.5"); // Deposit amount will be in WETH.
const BORROW_AMOUNT = ethers.utils.parseUnits("200", 6); // Borrow amount will be in USDC (6 decimals).

if (ORIGIN_CHAIN == DEST_CHAIN) {
  throw "NETWORK in ./packages/hardhat/.env and DEST_CHAIN cannot be the same";
}

console.log("Testing XFuji + Connext deposit and borrow\n\n");

const checkUserEthBal = async () => {
  const bal = await testSigner.getBalance();
  if(bal.isZero()) {
    throw "Test user defined by PRIVATE_KEY in .env must have some tesnet ETH";
  }
}

const prestage = async () => {
  await checkUserEthBal();
  console.log("...pre-staging test user with collateral");
  let test = await ethers.getContractAt("IERC20Mintable", connextData[ORIGIN_CHAIN].TestToken.address);
  test = test.connect(testSigner);
  let tx = await test.mint(testSigner.address, DEPOSIT_AMOUNT);
  await tx.wait();
  console.log("...erc20 approval of 'collateral' to connext handler");
  tx = await test.approve(connextData[ORIGIN_CHAIN].ConnextHandler.address, DEPOSIT_AMOUNT);
  await tx.wait();
};

const main = async () => {

  await prestage();

  console.log("...building XCall parameters");
  const router = await ethers.getContractAt("Router", xFujiDeployments[ORIGIN_CHAIN].router);
  const utx = await router.populateTransaction.depositBorrowAndBridgeTestnet(
    xFujiDeployments[DEST_CHAIN].vault,
    DEPOSIT_AMOUNT,
    BORROW_AMOUNT,
    testSigner.address,
    connextData[DEST_CHAIN].domainId
  );

  let handler = await ethers.getContractAt("IConnext", connextData[ORIGIN_CHAIN].ConnextHandler.address);
  handler = handler.connect(testSigner);

  const calledContract = xFujiDeployments[DEST_CHAIN].router;

  const callParams = {
    to: calledContract, // the address that should receive the funds
    callData: utx.data, // call router method depositBorrowAndBridgeTestnet()
    originDomain: connextData[ORIGIN_CHAIN].domainId, // send from CHAIN_NAME
    destinationDomain: connextData[DEST_CHAIN].domainId, // to DEST_CHAIN
    agent: calledContract, // address allowed to execute in addition to relayers  
    recovery: calledContract, // fallback address to send funds to if execution fails on destination side
    forceSlow: false, // option that allows users to take the Nomad slow path (~30 mins) instead of paying routers a 0.05% fee on their transaction
    receiveLocal: false, // option for users to receive the local Nomad-flavored asset instead of the adopted asset on the destination side
    callback: ethers.constants.AddressZero, // zero address because we don't expect a callback for a simple transfer 
    callbackFee: "0", // relayers on testnet don't take a fee
    relayerFee: "0", // relayers on testnet don't take a fee
    slippageTol: "9995" // max basis points allowed due to slippage (9995 to tolerate .05% slippage)
  };

  const xCallArgs = {
    params: callParams,
    transactingAssetId: connextData[ORIGIN_CHAIN].TestToken.address, // the Connext Test Token
    amount: DEPOSIT_AMOUNT
  };

  console.log("...sending Xcall");
  const xcallTxReceipt = await handler.xcall(xCallArgs /*,{gasLimit: ethers.BigNumber.from("30000000")}*/);
  await xcallTxReceipt.wait();
  console.log(xcallTxReceipt); // so we can see the transaction hash
  console.log("Xcall Test complete!");
  console.log("Read this experiment README.md file at root of this package.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});