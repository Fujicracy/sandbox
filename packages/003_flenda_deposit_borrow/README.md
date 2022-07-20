## Experiment 003_flenda_deposit_borrow


This experiment showcases a user who wants to deposit-and-borrow crosschain in the following way:
1. A cross call is originated from Chain A, using Connext Amarokv2.0 to relay message.
2. When message is received on Chain B, a simplified Fuji instance makes a deposit-borrow operation on chain B.
3. When funds are received fuji instances sends funds back to Chain A.  

#### Notes
Set up an `.env` file with
`INFURA_ID=<your-key>`