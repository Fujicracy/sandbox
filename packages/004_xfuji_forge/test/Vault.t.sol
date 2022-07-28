// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IConnextHandler} from "nxtp/core/connext/interfaces/IConnextHandler.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {Vault, ERC20} from "../src/Vault.sol";
import {Router} from "../src/Router.sol";
import {IWETH9} from "../src/helpers/PeripheryPayments.sol";
import {AaveV3Goerli} from "../src/providers/goerli/AaveV3Goerli.sol";
import {AaveV3Rinkeby} from "../src/providers/rinkeby/AaveV3Rinkeby.sol";
import {ILendingProvider} from "../src/interfaces/ILendingProvider.sol";

interface IMintableWETH {
  function mint(address, uint256) external;
}

contract VaultTest is DSTestPlus {
  uint256 goerliFork;
  uint256 rinkebyFork;

  Vault public vault;
  Router public router;
  ILendingProvider public aaveV3;

  IWETH9 public weth;
  IConnextHandler public connextHandler;

  address public connextTestToken;
  address public asset;
  address public debtAsset;
  address public oracle;

  function setUp() public {
    goerliFork = vm.createFork("goerli");
    rinkebyFork = vm.createFork("rinkeby");
    /*_setUpRinkeby();*/
    _setUpGoerli();
  }

  function _setUpGoerli() internal {
    vm.selectFork(goerliFork);

    weth = IWETH9(0x2e3A2fb8473316A02b8A297B982498E661E1f6f5);
    connextHandler = IConnextHandler(0x6c9a905Ab3f4495E2b47f5cA131ab71281E0546e);
    connextTestToken = 0x26FE8a8f86511d678d031a022E48FfF41c6a3e3b;

    asset = 0x2e3A2fb8473316A02b8A297B982498E661E1f6f5; // weth
    debtAsset = 0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43; // usdc
    oracle = 0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C;

    aaveV3 = new AaveV3Goerli();
    router = new Router(weth, connextHandler);

    vault = new Vault(
      asset,
      debtAsset,
      oracle,
      address(router)
    );

    vault.setActiveProvider(aaveV3);
    router.registerVault(IVault(address(vault)));

    router.setRouter(1111, address(0xA));
    router.setTestnetToken(connextTestToken);
  }

  function _setUpRinkeby() internal {
    vm.selectFork(rinkebyFork);

    weth = IWETH9(0xd74047010D77c5901df5b0f9ca518aED56C85e8D);
    connextHandler = IConnextHandler(0x4cAA6358a3d9d1906B5DABDE60A626AAfD80186F);
    connextTestToken = 0x3FFc03F05D1869f493c7dbf913E636C6280e0ff9;

    asset = 0xd74047010D77c5901df5b0f9ca518aED56C85e8D; // weth
    debtAsset = 0xb18d016cDD2d9439A19f15633005A6b2cd6Aa774; // usdc
    oracle = 0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C;

    aaveV3 = new AaveV3Rinkeby();
    router = new Router(weth, connextHandler);

    vault = new Vault(
      asset,
      debtAsset,
      oracle,
      address(router)
    );

    vault.setActiveProvider(aaveV3);
    router.registerVault(IVault(address(vault)));

    router.setRouter(3331, address(0xA));
    router.setTestnetToken(connextTestToken);
  }

  function testConfigs() public {
    assertEq(vault.asset(), asset);
    assertEq(vault.debtAsset(), debtAsset);
    assertEq(address(vault.activeProvider()), address(aaveV3));
  }

  function testDepositAndWithdraw() public {
    address userChainA = address(0xA);
    vm.label(address(userChainA), "userChainA");

    /*vm.deal(userChainA, amount);*/
    uint256 amount = 2 ether;
    IMintableWETH(address(weth)).mint(userChainA, amount);
    assertEq(weth.balanceOf(userChainA), amount);

    vm.startPrank(userChainA);

    SafeTransferLib.safeApprove(weth, address(vault), amount);
    vault.deposit(amount, userChainA);

    assertEq(vault.balanceOf(userChainA), amount);
    vault.withdraw(amount, userChainA, userChainA);
    assertEq(vault.balanceOf(userChainA), 0);
    assertEq(weth.balanceOf(userChainA), amount);
  }

  function testDepositAndWithdrawFromRouter() public {
    address userChainA = address(0xA);
    vm.label(address(userChainA), "userChainA");

    /*vm.deal(userChainA, amount);*/
    uint256 amount = 2 ether;
    IMintableWETH(address(weth)).mint(userChainA, amount);
    assertEq(weth.balanceOf(userChainA), amount);

    vm.startPrank(userChainA);

    SafeTransferLib.safeApprove(weth, address(router), type(uint256).max);
    router.depositToVault(IVault(address(vault)), amount);

    assertEq(vault.balanceOf(userChainA), amount);
    router.withdrawFromVault(IVault(address(vault)), amount);
    assertEq(vault.balanceOf(userChainA), 0);
    assertEq(weth.balanceOf(userChainA), amount);
  }
}
