import { createMachine, assign, InterpreterFrom } from "xstate"

import Onboard from "@web3-onboard/core"
import injectedModule from "@web3-onboard/injected-wallets"
// import { initializeWalletModules } from "@web3-onboard/core/dist/store/actions"

const MAINNET_RPC_URL = "https://mainnet.infura.io/v3/<INFURA_KEY>"

const injected = injectedModule()

const onboard = Onboard({
  wallets: [injected],
  chains: [
    {
      id: "0x1",
      token: "ETH",
      label: "Ethereum Mainnet",
      rpcUrl: MAINNET_RPC_URL,
    },
  ],
})

const logIn = () =>
  onboard.connectWallet().then(wallets => {
    if (wallets[0]) {
      return wallets[0]
    }
    return Promise.reject("No wallet found.")
  })

// console.log(wallets)

// if (wallets[0]) {
//   // create an ethers provider with the last connected wallet provider
//   const ethersProvider = new ethers.providers.Web3Provider(
//     wallets[0].provider,
//     'any'
//   )

//   const signer = ethersProvider.getSigner()

//   // send a transaction with the ethers provider
//   const txn = await signer.sendTransaction({
//     to: '0x',
//     value: 100000000000000
//   })

//   const receipt = await txn.wait()
//   console.log(receipt)
// }

const authMachine = createMachine({
  id: "auth",
  initial: "initial",
  context: {} as {
    user: object
    error: string
  },
  events: {} as { type: "INITIALIZE" } | { type: "LOGOUT" },
  states: {
    initial: {
      on: {
        INITIALIZE: "pending",
      },
    },
    pending: {
      invoke: {
        id: "login",
        src: () => logIn(),
        onDone: {
          target: "loggedIn",
          actions: assign({ user: (context, event) => event.data.accounts[0] }),
        },
        onError: {
          target: "error",
          actions: assign({ error: (context, event) => event.data }),
        },
      },
    },
    loggedIn: {
      on: {
        LOGOUT: {
          target: "initial",
          actions: assign({ user: undefined, error: undefined }),
        },
      },
    },
    // loggedOut: {}, // Should we differentiate state if user logged out or if it's initial ?
    error: {
      on: {
        INITIALIZE: {
          target: "pending",
          actions: assign({ error: undefined }),
        },
      },
    },
  },
})

export type AuthStateMachine = InterpreterFrom<typeof authMachine>

export { authMachine }
