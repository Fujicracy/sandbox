// Log keeping of cross call txs and learnings.

const TransactionsLogs = {
  goerli: {
    tx0: {
      hash: "0x641717d1d112addfabd90422e733a4f6f138e1ebd6c81ad2c3048327caf88598",
      transferId: "0x099b4d0804ab3d770597424039d1df38e394cf8e5b645a3007d65ec067a90ebb",
      comments: "Failed because test token was assummed to be in contract control, need to pull with erc20.transferFrom()"
    },
    tx1: {
      hash: "0x81276eb1fbbdbacdbdafa04ee3fdf43c4cb208305418cfa5a310e2baea264f62",
      transferId: "0x463a784f863a83155529f8a368cd3f27cf0dac57c94c795207525e1b92d3e87a",
      comments: "Pending..might fail due to wrong destination domainId"
    },
    tx2: {
      hash: "",
      transferId: "",
      comments: ""
    }
  },
  rinkeby: {
    tx0: {
      hash: "0xcef123aba59c18216144eeed13106a18107ae22951707c4776f90173f143497f",
      transferId: "0x97446f179053dae041e1ff624a153522ffdd3569bdd9afc2cb7c1c0a4b6f5900",
      comments: "Pending"
    },
    tx1: {
      hash: "0xdb7ec3db8d2ca94d6f25e554f750f7aec051b7b13873ea3df404419b13ce3364",
      transferId: "0xeb352145389ef23efabe58be28f5c068bb7745401bcff87e08e1f564ef3d91b3",
      comments: "Pending. Cross-ping rinkeby => goerli"
    }
  }
}