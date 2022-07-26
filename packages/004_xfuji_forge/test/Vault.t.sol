// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IConnextHandler} from "nxtp/core/connext/interfaces/IConnextHandler.sol";
import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {Vault} from "../src/Vault.sol";
import {Router, IWETH9} from "../src/Router.sol";
import {AaveV3Goerli} from "../src/providers/goerli/AaveV3Goerli.sol";
import {ILendingProvider} from "../src/interfaces/ILendingProvider.sol";

contract VaultTest is DSTestPlus {
  uint256 goerliFork;
  uint256 rinkebyFork;

  Vault public vault;
  Router public router;
  ILendingProvider public aaveV3;

  // Goerli addresses ------>
  IWETH9 public weth = IWETH9(0x2e3A2fb8473316A02b8A297B982498E661E1f6f5);
  IConnextHandler public connextHandler = IConnextHandler(0x6c9a905Ab3f4495E2b47f5cA131ab71281E0546e);

  address public asset = 0x2e3A2fb8473316A02b8A297B982498E661E1f6f5; // weth
  address public debtAsset = 0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43; // usdc
  address public oracle = 0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C;
  // <------

  function setUp() public {
    goerliFork = vm.createFork("goerli");
    vm.selectFork(goerliFork);

    aaveV3 = new AaveV3Goerli();
    router = new Router(weth, connextHandler);

    Vault.Factor memory maxLtv = Vault.Factor(75, 100);
    Vault.Factor memory liqRatio = Vault.Factor(5, 100);
    vault = new Vault(
      asset,
      debtAsset,
      oracle,
      address(router),
      maxLtv,
      liqRatio
    );

    vault.setActiveProvider(aaveV3);
  }

  function testConfigs() public {
    assertEq(vault.asset(), asset);
    assertEq(vault.debtAsset(), debtAsset);
    assertEq(address(vault.activeProvider()), address(aaveV3));
  }

  function testDeposit() public {
    address userChainA = address(0xA);
    vm.label(address(userChainA), "userChainA");

    uint256 amount = 1 ether;
    weth.deposit{ value: amount }();
    SafeTransferLib.safeTransferFrom(weth, address(this), userChainA, amount);
    assertEq(weth.balanceOf(userChainA), amount);

    vm.startPrank(userChainA);

    SafeTransferLib.safeApprove(weth, address(vault), amount);
    vault.deposit(amount, userChainA);

    assertEq(vault.balanceOf(userChainA), amount);
  }
}
