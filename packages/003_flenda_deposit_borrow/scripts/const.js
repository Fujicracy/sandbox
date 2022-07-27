const connextData = {
  rinkeby: {
    chainId: 4,
    domainId: 1111,
    ConnextHandler: {
      address: "0x4cAA6358a3d9d1906B5DABDE60A626AAfD80186F",
    },
    PromiseRouter: {
      address: "0xC02530858cE0260a1c4f214CF2d5b7c4E5986485"
    },
    TestToken: {
      address: "0x3FFc03F05D1869f493c7dbf913E636C6280e0ff9"
    }
  },
  goerli: {
    chainId: 5,
    domainId: 3331,
    ConnextHandler: {
      address: "0x6c9a905Ab3f4495E2b47f5cA131ab71281E0546e",
    },
    PromiseRouter: {
      address: "0xD7DAE26f3C54CEE823a02C6fD25d4301860F2B33",
    },
    TestToken: {
      address: "0x26FE8a8f86511d678d031a022E48FfF41c6a3e3b"
    }
  }
}

const aaveV3Data = {
  rinkeby: {
    pool: "0xE039BdF1d874d27338e09B55CB09879Dedca52D8",
    dataProvider: "0xBAB2E7afF5acea53a43aEeBa2BA6298D8056DcE5",
    assets: {
      weth: "0xd74047010D77c5901df5b0f9ca518aED56C85e8D",
      aweth: "0x608D11E704baFb68CfEB154bF7Fd641120e33aD4",
      usdc: "0xb18d016cDD2d9439A19f15633005A6b2cd6Aa774",
      ausdc: "0x50b283C17b0Fc2a36c550A57B1a133459F4391B3"
    },
  },
  goerli: {
    pool: "0x368EedF3f56ad10b9bC57eed4Dac65B26Bb667f6",
    dataProvider: "0x9BE876c6DC42215B00d7efe892E2691C3bc35d10",
    assets: {
      weth: "0x2e3A2fb8473316A02b8A297B982498E661E1f6f5",
      aweth: "0x27B4692C93959048833f40702b22FE3578E77759",
      usdc: "0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43",
      ausdc: "0x1Ee669290939f8a8864497Af3BC83728715265FF"
    }
  }
}

// MockEACAggregatorProxy.sol
const mockOracleData = {
  rinkeby: {
    weth: "0xF188a4504E0D3a5446eb99340d709C148f2768f7",
    usdc: "0x47bbaC2eaE84D2b82123BB483E307C614a5eAC4e",
  },
  goerli: {
    weth: "0xF188a4504E0D3a5446eb99340d709C148f2768f7",
    usdc: "0x47bbaC2eaE84D2b82123BB483E307C614a5eAC4e"
  }
}

const xFujiDeployments = {
  rinkeby: {
    unwrapper: "0xBB73511B0099eF355AA580D0149AC4C679A0B805",
    aaveV3: "0xc5d5a86E9f752e241eAc96a0595E4Cd6adc05F5a",
    oracle: "0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C",
    vault: "0x459B490F86e6B7C86086511D6a378f8C4b313D17",
    mapper: "0x2a6CE9bb134547dce7dF563cefD17885264F6B41",
    router: "0x6880eE32F0C5175bEb94D1712f14Aa5F70Df1EcA",
  },
  goerli: {
    unwrapper: "0xBB73511B0099eF355AA580D0149AC4C679A0B805",
    aaveV3: "0xc5d5a86E9f752e241eAc96a0595E4Cd6adc05F5a",
    oracle: "0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C",
    vault: "0x459B490F86e6B7C86086511D6a378f8C4b313D17",
    mapper: "0x2a6CE9bb134547dce7dF563cefD17885264F6B41",
    router: "0xfB6C304d0CE193693eee21299D22b8979A6425F5",
  },
}

module.exports = {
  connextData,
  aaveV3Data,
  mockOracleData,
  xFujiDeployments
}