// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import {IConnextHandler} from "nxtp/core/connext/interfaces/IConnextHandler.sol";
import {Vault} from "./Vault.sol";
import {Router} from "./Router.sol";
import {IWETH9} from "./helpers/PeripheryPayments.sol";
import {AaveV3Goerli} from "./providers/goerli/AaveV3Goerli.sol";
import {AaveV3Rinkeby} from "./providers/rinkeby/AaveV3Rinkeby.sol";
import {ILendingProvider} from "./interfaces/ILendingProvider.sol";
import {IVault} from "./interfaces/IVault.sol";

contract DeployerTestnet {

  struct Registry {
    address asset;
    address debtAsset;
    address oracle;
    address weth;
    address testToken;
    address connextHandler;
  }

  struct Deploys {
    Vault vault;
    Router router;
    ILendingProvider provider;
  }

  Vault.Factor maxLtv = Vault.Factor(75, 100);
  Vault.Factor liqRatio = Vault.Factor(5, 100);

  // Domains
  // goerli -> 3331
  // rinkeby -> 1111

  mapping(uint32 => Registry) public registryByDomain;
  mapping(uint32 => Deploys) public deploysByDomain;

  constructor() {
    Registry memory goerli = Registry({
      asset: 0x2e3A2fb8473316A02b8A297B982498E661E1f6f5,
      debtAsset: 0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43,
      oracle: 0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C,
      weth: 0x2e3A2fb8473316A02b8A297B982498E661E1f6f5,
      testToken: 0x26FE8a8f86511d678d031a022E48FfF41c6a3e3b,
      connextHandler: 0x6c9a905Ab3f4495E2b47f5cA131ab71281E0546e
    });
    registryByDomain[3331] = goerli;

    Registry memory rinkeby = Registry({
      asset: 0xd74047010D77c5901df5b0f9ca518aED56C85e8D,
      debtAsset: 0xb18d016cDD2d9439A19f15633005A6b2cd6Aa774,
      oracle: 0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C,
      weth: 0xd74047010D77c5901df5b0f9ca518aED56C85e8D,
      testToken: 0x3FFc03F05D1869f493c7dbf913E636C6280e0ff9,
      connextHandler: 0x4cAA6358a3d9d1906B5DABDE60A626AAfD80186F
    });
    registryByDomain[1111] = rinkeby;
  }

  function deploy(uint32 domain) external {
    Registry memory reg = registryByDomain[domain]; 
    if (reg.asset == address(0)) {
      revert("No registry for this chain");
    }

    ILendingProvider aaveV3;
    if (domain == 3331) {
      aaveV3 = new AaveV3Goerli();
    } else {
      aaveV3 = new AaveV3Rinkeby();
    }
    Router router = new Router(
      IWETH9(reg.weth),
      IConnextHandler(reg.connextHandler)
    );
    Vault vault = new Vault(
      reg.asset,
      reg.debtAsset,
      reg.oracle,
      address(router)
    );

    deploysByDomain[domain].vault = vault;
    deploysByDomain[domain].router = router;
    deploysByDomain[domain].provider = aaveV3;

    // Configs
    vault.setActiveProvider(aaveV3);
    router.registerVault(IVault(address(vault)));
    router.setTestnetToken(reg.testToken);
  }
}
