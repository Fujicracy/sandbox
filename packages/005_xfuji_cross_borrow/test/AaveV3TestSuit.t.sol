// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@/Vault.sol";
import "@/Router.sol";
import "@/providers/AaveV3.sol";
import "@/interfaces/IVault.sol";


abstract contract AaveV3TestSuit is Test {
  address user;
  address depositToken;
  address borrowToken;
  address connext;
  address testToken;

  Router router;
  Vault vault;
  IProvider provider;

  constructor(
    address _addressProvider, 
    address _depositToken, 
    address _borrowToken,
    address _connext,
    address _testToken
  ) {
    provider = new AaveV3(_addressProvider);
    depositToken = _depositToken;
    borrowToken = _borrowToken;
    connext = _connext;
    testToken = _testToken;
  }

  function setUp() public {
    IProvider[] memory providers = new IProvider[](1);
    providers[0] = provider;

    router = new Router(connext);

    vault = new Vault(
      depositToken,
      borrowToken,
      address(router),
      75,
      80,
      providers
    );

    router.addVault(address(vault));
    router.setTestToken(testToken);

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
