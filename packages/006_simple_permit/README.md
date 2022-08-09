## Experiment 006_simple_permit

This experiment showcases how the permit() function is used in the context of ERC20:  
1. Openzeppelin ERC20 extension implementation of permit is used to create a mock token. Such implementation integrates: [EIP2612](https://eips.ethereum.org/EIPS/eip-2612[EIP-2612]) and [EIP712](https://eips.ethereum.org/EIPS/eip-712)  
2. An extra contract 'PermitProcessor' is created to showcase the execution of ERC20.permit() + ERC20.transferFrom() in one call. 
3. Test scripts showcase how the permit is built with etherjs for the signer to sign message.

#### How to run test
1. Set up an `.env` file with the following:
- `PRIVATE_KEY_HARDHAT_TEST_SIGNER=<0x123456>` for a test user. You can get the private key of Hardhat's first signer by simply running: `npx hardhat node`

2. Then run the following:
- `yarn test`

#### Notes

- The following [article](https://medium.com/metamask/eip712-is-coming-what-to-expect-and-how-to-use-it-bb92fd1a7a26) is a bit old, but a good primer on some of the concepts needed to understand EIP712 in general and this experiment.
- To see the implementation of how to build permit's 'digest' from within solidity refer to getPermitDigest() in PermitProcessor.sol contract.
- To see how the front-end could handle the permit 'digest' for signing refer to **Tests No. 2**, and **Test No. 3** in `./test/permit_test.js`.

#### Additional Resources
- Metamask procedure to do signTypedData: [here](https://docs.metamask.io/guide/signing-data.html#sign-typed-data-v4)
- Etherjs procedure to do signTypedData from a Signer object: [here](https://docs.ethers.io/v5/api/signer/#Signer-signTypedData)
- Relevant issues regarding Ethersjs EIP712 implementation: [here](https://github.com/ethers-io/ethers.js/issues/687)