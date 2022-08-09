## Experiment 003_flenda_deposit_borrow


This experiment showcases a user who wants to deposit-and-borrow crosschain in the following way:
1. A cross call is originated from Chain A, using Connext Amarokv2.0 to relay message. The call is made directly to the ConnextHandler contract. xCalls params are built off-chain.
2. When message is received on Chain B, a Router(Fuji) instance receives the test token and makes a deposit-borrow operation at AaveV3. This is done through the Vault(Fuji built from ERC4626). Debt is recorded at the Vault on behalf the original caller.
3. The router receives the funds and makes a new xCall to the ConnextHandler to send funds back to user on Chain A. 

#### How to run a deposit and borrow cross test
1. Set up an `.env` file with the following:
- `INFURA_ID=<your-key>`
- `NETWORK=goerli` or `NETWORK=rinkeby` depending on what chain you want to initiate test.
- `PRIVATE_KEY=<0x123456>` for a test user. Ensure this address has some native test ETH balance on the initiating chain.

2. In the file `./test/runTest.js` set up the DEST_CHAIN in line 17
- `const DEST_CHAIN = '<chain_name>'; // Set up the destination chain` (currently only `rinkeby` or `goerli` are supported.)
- You can optionally modify the amounts too. 

3. Then run the following:
- `yarn test`

4. At the origin chain, after all cross calls have been performed succesfull, the provided test user should have some USDC balance.

5. See NOTES on how to track progress of your cross call. 

#### Notes

- It may take several minutes to hours for the test to complete on Connext side.  
- Follow Connext instructions [here](https://docs.connext.network/developers/xcall-status) to track your test call through the Connext flow.

#### How to make a PingMe cross test
1. Set up an `.env` file with the following:
- `INFURA_ID=<your-key>`
- `NETWORK=goerli` or `NETWORK=rinkeby` depending on what chain you want to initiate test.
- `PRIVATE_KEY=<0x123456>` for a test user. Ensure this address has some native test ETH balance on the initiating chain.

2. In the file `./test/crossPing.js` set up the DEST_CHAIN in line 16:
- `const DEST_CHAIN = '<chain_name>'; // Set up the destination chain` (currently only `rinkeby` or `goerli` are supported.)
- You can optionally modify the `UNIQUE_MESSAGE` too. This will be emitted in an event at the destination chain.

3. Then run the following:
- `yarn test:cross-ping`

4. At the destination chain, the totalPings() number will increase. You can check the contract addresses at: `./scripts/const.js` in the `xFujiDeployments` object.

5. See NOTES on how to track progress of your cross call. 
