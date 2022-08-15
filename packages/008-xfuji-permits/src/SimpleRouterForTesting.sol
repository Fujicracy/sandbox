// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.15;

import {IVault}  from "./IVault.sol";
import {BorrowingVault} from "./BorrowingVault.sol";
import {IConnext} from "./connext/IConnext.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Mintable} from "@xfuji/interfaces/IERC20Mintable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "@xfuji/interfaces/IWETH.sol";

contract SimpleRouterForTesting {
  using SafeERC20 for IERC20;

  enum Action {
    Deposit,
    Withdraw,
    Borrow,
    Payback,
    BridgeTransfer,
    permitAssets,
    permitDebt
  }

  IConnext public connext;
  // -------> On testnet ONLY
  address public connextTestToken;
  // <------

  IWETH immutable public WNATIVE;

  // ref: https://docs.nomad.xyz/developers/environments/domain-chain-ids
  mapping(uint256 => address) public routerByDomain;

  constructor(IConnext connext_, IWETH WNATIVE_) {
    connext = connext_;
    WNATIVE = WNATIVE_;
  }


  // 1. Bridge collateral asset to dest chain
  // 2. Deposit and Borrow on dest chain
  function bridgeDepositAndBorrow(
    uint256 destDomain,
    address destVault,
    address asset,
    uint256 amount,
    uint256 borrowAmount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    external
  {
    // verify destVault exists on destDomain?
    require(routerByDomain[destDomain] != address(0), "No router on dest domain");

    IERC20 token = IERC20(asset);
    token.safeTransferFrom(msg.sender, address(this), amount);

    // ------> On testnet ONLY
    // cannot transfer anything else than TEST token
    // that's why we pull user's asset but we bridge TEST token
    IERC20Mintable(connextTestToken).mint(address(this), amount);
    // <------

    Action[] memory actions = new Action[](3);
    bytes[] memory args = new bytes[](3);

    actions[0] = Action.Deposit;
    args[0] = abi.encode(amount, msg.sender);

    actions[1] = Action.permitDebt;
    args[1] = abi.encode(
      msg.sender,
      routerByDomain[destDomain],
      borrowAmount,
      deadline,
      v, r, s
    );

    actions[2] = Action.Borrow;
    args[2] = abi.encode(borrowAmount, msg.sender, msg.sender);

    bytes memory params = abi.encode(destVault, asset, amount, actions, args);

    bytes4 selector = bytes4(keccak256("bridgeCall(bytes)"));

    bytes memory callData = abi.encodeWithSelector(selector, params);

    _bridgeTransferWithCalldata(destDomain, asset, amount, callData);
  }

  // callable only from the bridge
  function bridgeCall(bytes memory params)
    external
  {
    (
      address vault,
      address bridgedAsset,
      uint256 bridgedAmount,
      Action[] memory actions,
      bytes[] memory args
    ) = abi.decode(params, (address, address, uint256, Action[], bytes[]));

    // TODO pull bridgedAsset whatever it is
    bridgedAsset;
    // If using fast liquidity "bridgedAmount" will be less than the one passed
    // from origin domain because of the fees. That's why in pullTokens we
    // have to account for the fee. If we are using sposored vaults, we don't
    // need to handle it here.
    /*pullToken(ERC20(connextTestToken), bridgedAmount, address(this));*/

    // -------> On testnet ONLY
    IERC20Mintable(address(WNATIVE)).mint(address(this), bridgedAmount);
    // <------

    uint256 len = actions.length;
    for (uint256 i = 0; i < len; i++) {
      if (actions[i] == Action.Deposit) {
        (uint256 amount, address receiver) = abi.decode(args[i], (uint256, address));
        IVault(vault).deposit(amount, receiver);
      } else if (actions[i] == Action.Withdraw) {
        (uint256 amount, address receiver, address owner) =
          abi.decode(args[i], (uint256, address, address));
        IVault(vault).withdraw(amount, receiver, owner);
      } else if (actions[i] == Action.Borrow) {
        (uint256 amount, address receiver, address owner) =
          abi.decode(args[i], (uint256, address, address));
        IVault(vault).borrow(amount, receiver, owner);
      } else if (actions[i] == Action.Payback) {
        (uint256 amount, address receiver) = abi.decode(args[i], (uint256, address));
        IVault(vault).payback(amount, receiver);
      } else if (actions[i] == Action.permitAssets) {
        (
          address owner,
          address spender,
          uint256 value,
          uint256 deadline,
          uint8 v, bytes32 r, bytes32 s
        ) = abi.decode(args[i],
          (address, address, uint256, uint256, uint8, bytes32, bytes32)
        );
        IVault(vault).permitAssets(
          owner,
          spender,
          value,
          deadline,
          v,r,s
        );
      } else if (actions[i] == Action.permitDebt) {
        (
          address owner,
          address spender,
          uint256 value,
          uint256 deadline,
          uint8 v, bytes32 r, bytes32 s
        ) = abi.decode(args[i],
          (address, address, uint256, uint256, uint8, bytes32, bytes32)
        );
        IVault(vault).permitDebt(
          owner,
          spender,
          value,
          deadline,
          v,r,s
        );
      }
    }
  }

  function _bridgeTransferWithCalldata(
    uint256 destDomain,
    address asset,
    uint256 amount,
    bytes memory callData
  )
    internal
  {
    IConnext.CallParams memory callParams = IConnext.CallParams({
      to: routerByDomain[destDomain],
      callData: callData,
      originDomain: uint32(connext.domain()),
      destinationDomain: uint32(destDomain),
      agent: msg.sender, // address allowed to transaction on destination side in addition to relayers
      recovery: msg.sender, // fallback address to send funds to if execution fails on destination side
      forceSlow: false, // option to force Nomad slow path (~30 mins) instead of paying 0.05% fee
      receiveLocal: false, // option to receive the local Nomad-flavored asset instead of the adopted asset
      callback: address(0), // this contract implements the callback
      callbackFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
      relayerFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
      slippageTol: 9995 // tolerate .05% slippage
    });

    asset;
    IConnext.XCallArgs memory xcallArgs = IConnext.XCallArgs({
      params: callParams,
      // ------> On testnet ONLY
      // replace connextTestToken by asset
      transactingAssetId: connextTestToken,
      // <------
      amount: amount
    });

    connext.xcall(xcallArgs);
  }

  ///////////////////////
  /// Admin functions ///
  ///////////////////////

  function setRouter(uint256 domain, address router) external {
    // TODO only owner
    // TODO verify params
    routerByDomain[domain] = router;
  }

  // -------> On testnet ONLY
  function setTestnetToken(address token) external {
    connextTestToken = token;
    IERC20(connextTestToken).approve(address(connext), type(uint256).max);
  }

  // <------

  function registerVault(IVault vault) external {
    // TODO onlyOwner
    address asset = vault.asset();
    IERC20 tokenAsset = IERC20(asset);
    tokenAsset.approve(address(vault), type(uint256).max);
    tokenAsset.approve(address(connext), type(uint256).max);

    address debtAsset = vault.debtAsset();
    IERC20 tokenDebtAsset = IERC20(debtAsset);
    tokenDebtAsset.approve(address(vault), type(uint256).max);
    tokenDebtAsset.approve(address(connext), type(uint256).max);
  }

}