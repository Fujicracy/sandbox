// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@/Vault.sol";
import "@/Router.sol";
import "@/providers/AaveV3.sol";
import "@/interfaces/IVault.sol";


contract AaveV3Test is Test {
  address user;
  address depositToken;
  address borrowToken;

  Router router;
  Vault vault;
  IProvider provider;

  function setUp() public {
    provider = new AaveV3(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
    depositToken = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    borrowToken = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    IProvider[] memory providers = new IProvider[](1);
    providers[0] = provider;

    router = new Router(address(0));

    vault = new Vault(
      depositToken,
      borrowToken,
      address(router),
      75,
      80,
      providers
    );

    router.addVault(address(vault));

    user = vm.addr(1);
    vm.label(user, "user");

    deal(depositToken, user, 1000 ether);
  }

  function testZeroDepositBalance() public {
    assertEq(0, provider.getDepositBalance(depositToken, address(vault)));
  }

  function testZeroBorrowBalance() public {
    assertEq(0, provider.getBorrowBalance(depositToken, address(vault)));
  }

  function testDeposit() public {
    uint256 depositAmount = 1 ether;

    vm.startPrank(user);
    IERC20(depositToken).approve(address(vault), depositAmount);
    router.deposit(IVault(address(vault)), depositAmount);

    assertEq(depositAmount, provider.getDepositBalance(depositToken, address(vault)));
  }

  function testWithdraw() public {
    uint256 depositAmount = 1 ether;

    uint256 balBefore = IERC20(depositToken).balanceOf(user);

    vm.startPrank(user);
    IERC20(depositToken).approve(address(vault), depositAmount);
    router.deposit(IVault(address(vault)), depositAmount);

    assertEq(IERC20(depositToken).balanceOf(user), balBefore - depositAmount);

    router.withdraw(IVault(address(vault)), depositAmount);

    assertEq(balBefore, IERC20(depositToken).balanceOf(user));
  }
}
