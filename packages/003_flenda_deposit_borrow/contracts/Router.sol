// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

// TODO inherit from SelfPermit, Multicall, PeripheryPayments 
// for additional functionalitites
// ref: https://github.com/fei-protocol/ERC4626/blob/main/src/ERC4626RouterBase.sol

// TODO to be put in ./interfaces
interface IVault {
  function depositTo(uint strategyId, uint amount, address onBehalf) external;

  function withdrawFrom(uint strategyId, uint amount, address onBehal) external;

  function borrowFrom(uint strategyId, uint amount, address onBehalf) external;

  // ...
}

contract Router {

  mapping(uint => address) public routerByChainId;

  function depositAndBorrow(
    IVault vault,
    uint strategyId,
    uint depositAmount,
    uint borrowAmount
  ) external {
    // pullTokens to vault
    vault.depositTo(strategyId, depositAmount, msg.sender);
    vault.borrowFrom(strategyId, borrowAmount, msg.sender);
  }

  // Move the whole deposit to another strategy on the same chain.
  function switchStrategies(
    IVault vault,
    uint fromId,
    uint toId,
    uint amount
  ) external {
    vault.withdrawFrom(fromId, amount, msg.sender);
    vault.depositTo(toId, amount, msg.sender);
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

