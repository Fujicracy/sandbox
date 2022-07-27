// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "nxtp/core/connext/libraries/LibConnextStorage.sol";
import "nxtp/core/connext/interfaces/IConnextHandler.sol";
import "nxtp/core/connext/interfaces/IExecutor.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IRouter.sol";
import "./helpers/PeripheryPayments.sol";

// TODO inherit from SelfPermit, Multicall
// for additional functionalitites
// ref: https://github.com/fei-protocol/ERC4626/blob/main/src/ERC4626RouterBase.sol

contract Router is IRouter, PeripheryPayments {
  IConnextHandler public connext;
  IExecutor public executor;

  // ref: https://docs.nomad.xyz/developers/environments/domain-chain-ids
  mapping(uint32 => address) public routerByDomain;

  // A modifier for permissioned function calls.
  // Note: This is an important security consideration. If your target
  //       contract function is meant to be permissioned, it must check
  //       that the originating call is from the correct domain and contract.
  //       Also, check that the msg.sender is the Connext Executor address.
  modifier onlyConnextExecutor(uint32 originDomain) {
    require(
      IExecutor(msg.sender).originSender() == routerByDomain[originDomain] &&
        IExecutor(msg.sender).origin() == originDomain &&
        msg.sender == address(executor),
      "Expected origin contract on origin domain called by Executor"
    );
    _;
  }

  constructor(IWETH9 weth, IConnextHandler connext_) PeripheryPayments(weth) {
    connext = connext_;
    executor = connext.executor();
  }

  function approveVault(IVault vault) external {
    // TODO onlyOwner
    approve(ERC20(vault.asset()), address(vault), type(uint256).max);
  }

  function depositAndBorrow(
    IVault vault,
    uint256 depositAmount,
    uint256 borrowAmount
  ) external {
    pullToken(ERC20(vault.asset()), depositAmount, address(this));

    vault.deposit(depositAmount, msg.sender);
    vault.borrow(borrowAmount, msg.sender, msg.sender);
  }

  function depositToVault(IVault vault, uint256 amount) external {
    pullToken(ERC20(vault.asset()), amount, address(this));

    vault.deposit(amount, msg.sender);
  }

  function withdrawFromVault(IVault vault, uint256 amount) external {
    vault.withdraw(amount, msg.sender, msg.sender);
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

  function bridgeDepositToVault(
    address asset,
    uint256 amount,
    uint32 destDomain,
    address destVault
  ) external {
    // verify destVault exists on destDomain?

    uint32 originDomain = uint32(connext.domain());
    pullToken(ERC20(asset), amount, address(this));
    approve(ERC20(asset), address(connext), type(uint256).max);

    bytes4 selector = bytes4(keccak256("authorizedBridgeCall(uint256,uint32,address,address)"));
    bytes memory callData = abi.encodeWithSelector(
      selector,
      amount,
      originDomain,
      destVault,
      msg.sender
    );

    CallParams memory callParams = CallParams({
      to: routerByDomain[destDomain],
      callData: callData,
      originDomain: originDomain,
      destinationDomain: destDomain,
      agent: msg.sender, // address allowed to transaction on destination side in addition to relayers
      recovery: msg.sender, // fallback address to send funds to if execution fails on destination side
      forceSlow: true, // option to force Nomad slow path (~30 mins) instead of paying 0.05% fee
      receiveLocal: false, // option to receive the local Nomad-flavored asset instead of the adopted asset
      callback: address(0), // this contract implements the callback
      callbackFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
      relayerFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
      slippageTol: 9995 // tolerate .05% slippage
    });

    XCallArgs memory xcallArgs = XCallArgs({
      params: callParams,
      transactingAssetId: asset,
      amount: amount
    });

    connext.xcall(xcallArgs);
  }

  // Move deposit to another strategy on a different chain.
  // function teleportDeposit(...) external;

  // callable only from the bridge
  function authorizedBridgeCall(
    uint256 amount,
    uint32 originDomain,
    address vault,
    address onBehalfOf
  ) external {
    // TODO: add modifier onlyConnextExecutor
    originDomain;

    IVault(vault).deposit(amount, onBehalfOf);
  }

  function setRouter(uint32 domain, address router) external {
    // TODO only owner
    // TODO verify params
    routerByDomain[domain] = router;
  }
}