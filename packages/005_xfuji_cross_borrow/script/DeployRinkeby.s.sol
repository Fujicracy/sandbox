// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "@/Vault.sol";
import "@/Router.sol";
import "@/providers/AaveV3.sol";

contract DeployRinkeby is Script {
  function setUp() public { }

  function run() public {
    vm.startBroadcast();

    IProvider[] memory providers = new IProvider[](1);
    providers[0] = new AaveV3(0xBA6378f1c1D046e9EB0F538560BA7558546edF3C);

    Router router = new Router(0x4cAA6358a3d9d1906B5DABDE60A626AAfD80186F);

    Vault vault = new Vault(
      0xd74047010D77c5901df5b0f9ca518aED56C85e8D,
      0xb18d016cDD2d9439A19f15633005A6b2cd6Aa774,
      address(router),
      75,
      80,
      providers
    );

    router.addVault(address(vault));
    router.setTestToken(0x3FFc03F05D1869f493c7dbf913E636C6280e0ff9);

    vm.stopBroadcast();
  }
}
