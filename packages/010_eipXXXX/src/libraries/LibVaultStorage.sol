// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {IERC20} from "../interfaces/IERC20.sol";
import {ILendingProvider} from "./../interfaces/ILendingProvider.sol";
import {IChief} from "./../interfaces/IChief.sol";
import {IFujiOracle} from "./../interfaces/IFujiOracle.sol";
import {VaultActions} from "./../interfaces/IVaultPausable.sol";
import {Math, Rounding} from "./openzeppelin/Math.sol";
import {Address} from "./openzeppelin/Address.sol";

struct AppStorage {
  VaultPropertyStorage properties;
  VaultAccountingStorage accounting;
  VaultExtAddrStorage extAddresses;
  VaultSecurityStorage security;
}

struct VaultPropertyStorage {
  string vaultName;
  string vaultSymbol;
  IERC20 asset;
  IERC20 debtAsset;
  uint8 assetDecimals;
  uint8 debtDecimals;
  uint256 minAmount;
  uint256 maxLtv;
}

struct VaultAccountingStorage {
  uint256 totalAssetShareSupply;
  uint256 totalDebtShareSupply;
  ///@dev mapping structure: owner => shares
  mapping(address => uint256) assetShareBalances;
  ///@dev mapping structure: owner => shares
  mapping(address => uint256) debtShareBalances;
  /// @dev Allowance mapping structure: owner => operator => receiver => amount.
  mapping(address => mapping(address => mapping(address => uint256))) withdrawAllowance;
  /// @dev Allowance mapping structure: owner => operator => receiver => amount.
  mapping(address => mapping(address => mapping(address => uint256))) debtAllowance;
}

struct VaultExtAddrStorage {
  IChief chief;
  IFujiOracle oracle;
  ILendingProvider activeProvider;
  ILendingProvider[] providers;
}

struct VaultSecurityStorage {
  mapping(VaultActions => bool) actionsPaused;
}

library LibVaultLogic {
  using Address for address;
  using Math for uint256;

  /**
   * @dev Conversion function from `assets` to shares equivalent with support for rounding direction.
   * Requirements:
   * - Must return zero if `assets` or `totalSupply()` == 0.
   * - Must revert if `totalAssets` is not > 0.
   *   (Corresponds to a case where you divide by zero.)
   *
   * @param assets amount to convert to shares
   * @param totalAssets read from totalAssets()
   * @param shareSupply existing in this vault
   * @param rounding direction of division remainder
   */
  function _convertToShares(
    uint256 assets,
    uint256 totalAssets,
    uint256 shareSupply,
    Rounding rounding
  )
    internal
    pure
    returns (uint256 shares)
  {
    return
      (assets == 0 || shareSupply == 0) ? assets : assets.mulDiv(shareSupply, totalAssets, rounding);
  }

  function _convertToAssets(
    uint256 shares,
    uint256 totalAssets,
    uint256 shareSupply,
    Rounding rounding
  )
    internal
    pure
    returns (uint256 assets)
  {
    return (shareSupply == 0) ? shares : shares.mulDiv(totalAssets, shareSupply, rounding);
  }

  /**
   * @dev Execute an action at provider.
   *
   * @param assets amount handled in this action
   * @param name string of the method to call
   * @param provider to whom action is being called
   */
  function _executeProviderAction(
    uint256 assets,
    string memory name,
    ILendingProvider provider
  )
    internal
  {
    bytes memory data = abi.encodeWithSignature(
      string(abi.encodePacked(name, "(uint256,address)")), assets, address(this)
    );
    address(provider).functionDelegateCall(
      data, string(abi.encodePacked(name, ": delegate call failed"))
    );
  }

  /**
   * @dev Returns how much free 'assets' a user can withdraw or transfer
   * given their `balanceOfDebt()` and collateralization.
   * Requirements:
   * - Must be feed price from {FujiOracle} using {getPriceOf(asset(), debtAsset(), assetDecimals())}
   *
   * @param assets used as collateral
   * @param debt outstanding
   * @param debtDecimals of the debt asset {IERC20Metadata-decimals()}
   * @param price of `debt` in terms of `asset` expressed in asset decimals
   * @param maxLtv ratio allowed for this vault's asset (collateral)
   */
  function _computeFreeAssets(
    uint256 assets,
    uint256 debt,
    uint8 debtDecimals,
    uint256 price,
    uint256 maxLtv
  )
    internal
    pure
    returns (uint256 freeAssets)
  {
    if (debt == 0) {
      // Handle no debt case.
      freeAssets = assets;
    } else if (assets == 0 || price == 0 || maxLtv == 0) {
      // Handle zero price and/or zero maxLtv cases.
      freeAssets = 0;
    } else {
      uint256 lockedAssets = debt.mulDiv(1e18 * price, maxLtv * 10 ** debtDecimals);

      if (lockedAssets == 0) {
        // Handle wei level amounts in where 'lockedAssets' < 1 wei.
        lockedAssets = 1;
      }

      freeAssets = assets > lockedAssets ? assets - lockedAssets : 0;
    }
  }

  /**
   * @dev Returns balance of `asset` or `debtAsset` of this vault at all
   * listed providers in `_providers` array.
   *
   * @param method string method to call: "getDepositBalance" or "getBorrowBalance"
   * @param providers at where to check balance
   */
  function _checkProvidersBalance(
    string memory method,
    ILendingProvider[] memory providers
  )
    internal
    view
    returns (uint256 assets)
  {
    uint256 len = providers.length;
    bytes memory callData = abi.encodeWithSignature(
      string(abi.encodePacked(method, "(address,address)")), address(this), address(this)
    );
    bytes memory returnedBytes;
    for (uint256 i = 0; i < len;) {
      returnedBytes = address(providers[i]).functionStaticCall(callData, ": balance call failed");
      assets += uint256(bytes32(returnedBytes));
      unchecked {
        ++i;
      }
    }
  }
}
