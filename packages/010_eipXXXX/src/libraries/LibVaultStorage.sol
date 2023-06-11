// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {IERC20} from "../interfaces/IERC20.sol";
import {ILendingProvider} from "./../interfaces/ILendingProvider.sol";
import {VaultActions} from "./../interfaces/IVaultPausable.sol";
import {Math, Rounding} from "./openzeppelin/Math.sol";
import {Address} from "./openzeppelin/Address.sol";

struct AppStorage {
  string vaultName;
  string vaultSymbol;
  IERC20 asset;
  IERC20 debtAsset;
  mapping(address => uint256) assetShareBalances;
  mapping(address => uint256) debtShareBalances;
  uint256 totalAssetShareSupply;
  uint256 totalDebtShareSupply;
  uint8 assetDecimals;
  uint8 debtDecimals;
  ILendingProvider[] providers;
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

  function _computeFreeAssets(
    address owner,
    uint256 totalAssets_
  )
    internal
    view
    override
    returns (uint256 freeAssets)
  {
    uint256 debtShares = _debtShares[owner];
    uint256 assets = _convertToAssets(balanceOf(owner), totalAssets_, Math.Rounding.Down);

    // Handle no debt case.
    if (debtShares == 0) {
      freeAssets = assets;
    } else {
      uint256 debt = _convertToDebt(debtShares, totalDebt(), Math.Rounding.Up);
      uint256 price = oracle.getPriceOf(asset(), debtAsset(), decimals());
      uint256 lockedAssets = (debt * 1e18 * price) / (maxLtv * 10 ** _debtDecimals);

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
    string method,
    ILendingProvider[] providers
  )
    view
    internal
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
