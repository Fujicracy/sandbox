// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "../src/Vault.sol";
import "../src/providers/AaveV3.sol";


contract AaveV3Test is Test {
  address user;
  address depositToken;
  address borrowToken;

  Vault vault;
  IProvider provider;

  function setUp() public {
    provider = new AaveV3(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
    depositToken = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    borrowToken = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    IProvider[] memory providers = new IProvider[](1);
    providers[0] = provider;

    vault = new Vault(
      depositToken,
      borrowToken,
      address(0),
      75,
      80,
      providers
    );

    user = 0x32d4703e5834F1b474B17DFdB0aC32Cc22575145;
    vm.label(user, "user");
  }

  function testZeroDepositBalance() public {
    assertEq(0, provider.getDepositBalance(depositToken, address(vault)));
  }

  function testZeroBorrowBalance() public {
    assertEq(0, provider.getBorrowBalance(depositToken, address(vault)));
  }

  function testDeposit() public {
    uint256 depositAmount = 1e18;
    vm.startPrank(user);

    IERC20(depositToken).approve(address(vault), depositAmount);
    vault.deposit(depositAmount, user);

    assertEq(depositAmount, provider.getDepositBalance(depositToken, address(vault)));
  }
}
