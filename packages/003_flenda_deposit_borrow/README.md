## Experiment 003_flenda_deposit_borrow


This experiment showcases a user who wants to deposit-and-borrow crosschain in the following way:
1. A cross call is originated from Chain A, using Connext Amarokv2.0 to relay message.
2. When message is received on Chain B, a simplified Fuji instance makes a deposit-borrow operation on chain B.
3. When funds are received fuji instances sends funds back to Chain A.  

#### How to run test
1. Set up an `.env` file with the following:
- `INFURA_ID=<your-key>`
- `NETWORK=goerli` or `NETWORK=rinkeby` depending on what chain you want to initiate test.
- `PRIVATE_KEY=<0x123456>` for a test user. Ensure this address has some native test ETH balance on the initiating chain.

2. Then run the following:
- `yarn test`

3. At then the provided test user should have some USDC balance.

#### Notes

- It may take several minutes to hours for the test to complete on Connext side.  
- Follow Connext instructions [here](https://docs.connext.network/developers/xcall-status) to track your test call through the Connext flow.