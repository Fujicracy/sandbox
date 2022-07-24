// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "./interfaces/IVault.sol";
import "./helpers/PeripheryPayments.sol";

// TODO inherit from SelfPermit, Multicall, PeripheryPayments
// for additional functionalitites
// ref: https://github.com/fei-protocol/ERC4626/blob/main/src/ERC4626RouterBase.sol

contract Router is PeripheryPayments {
  mapping(uint256 => address) public routerByChainId;

  constructor(IWETH9 weth) PeripheryPayments(weth) {}

  function depositAndBorrow(
    IVault vault,
    uint256 depositAmount,
    uint256 borrowAmount
  ) external {
    pullToken(ERC20(vault.asset()), depositAmount, address(this));

    vault.deposit(depositAmount, msg.sender);
    vault.borrow(borrowAmount, msg.sender, msg.sender);
  }

  function depositETHAndBorrow(IVault vault, uint256 borrowAmount) external payable {
    wrapWETH9();
    vault.deposit(msg.value, msg.sender);
    vault.borrow(borrowAmount, msg.sender, msg.sender);
  }

  // Move the whole deposit to another strategy on the same chain.
  function switchVaults(
    IVault vaultFrom,
    IVault vaultTo,
    uint256 amount
  ) external {
    vaultFrom.withdraw(amount, address(this), msg.sender);
    vaultTo.deposit(amount, msg.sender);
  }

  // Move deposit to another strategy on a different chain.
  // function teleportDeposit(...) external;

  // callable only from the bridge
  // function authorizedBridgeCall(...) external {
  // check origin domain of the source contract
  // check msg.sender of xcall from the origin domain: it has to be another router
  // depositTo() or withdrawFrom() or borrowFrom() or paybackTo()
  // }
}
