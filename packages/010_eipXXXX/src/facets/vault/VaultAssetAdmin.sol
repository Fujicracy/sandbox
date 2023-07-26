// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {AppStorage} from "./../../libraries/LibVaultStorage.sol";
import {SystemAccessControl} from "../../access/SystemAccessControl.sol";
import {IVaultAdmin, ILendingProvider} from "../../interfaces/IVaultAdmin.sol";
import {SafeERC20, IERC20} from "../../libraries/openzeppelin/SafeERC20.sol";

contract VaultAssetAdmin is IVaultAdmin, SystemAccessControl {
  using SafeERC20 for IERC20;

  AppStorage internal s;

  /// Custom errors
  error VaultAssetAdmin__setter_invalidInput();

  /// @inheritdoc IVaultAdmin
  function setProviders(ILendingProvider[] memory providers)
    external
    onlyTimelock(s.extAddresses.chief)
  {
    _setProviders(providers);
  }

  /// @inheritdoc IVaultAdmin
  function setActiveProvider(ILendingProvider activeProvider_)
    external
    override
    onlyTimelock(s.extAddresses.chief)
  {
    _setActiveProvider(activeProvider_);
  }

  /**
   * @dev Returns true if `provider` is in `_providers` array.
   *
   * @param provider address
   */
  function _isValidProvider(address provider) internal view returns (bool check) {
    ILendingProvider[] memory storedProviders = s.extAddresses.providers;
    uint256 len = storedProviders.length;
    for (uint256 i = 0; i < len;) {
      if (provider == address(storedProviders[i])) {
        check = true;
        break;
      }
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Sets the `activeProvider` of this vault.
   * Requirements:
   * - Must emit an ActiveProviderChanged event.
   *
   * @param activeProvider_ address to be set
   */
  function _setActiveProvider(ILendingProvider activeProvider_) internal {
    // @dev skip validity check when setting it for the 1st time
    if (
      !_isValidProvider(address(activeProvider_))
        && address(s.extAddresses.activeProvider) != address(0)
    ) {
      revert VaultAssetAdmin__setter_invalidInput();
    }
    s.extAddresses.activeProvider = activeProvider_;
    emit ActiveProviderChanged(activeProvider_);
  }

  /**
   * @dev Sets the providers of this vault.
   * Requirements:
   * - Must be implemented at {BorrowingVault} or {YieldVault} level.
   * - Must infinite approve erc20 transfers of `asset` or `debtAsset` accordingly.
   * - Must emit a ProvidersChanged event.
   *
   * @param providers array of addresses
   */
  function _setProviders(ILendingProvider[] memory providers) internal {
    uint256 len = providers.length;
    for (uint256 i = 0; i < len;) {
      if (address(providers[i]) == address(0)) {
        revert VaultAssetAdmin__setter_invalidInput();
      }
      IERC20 asset_ = s.properties.asset;
      asset_.forceApprove(
        providers[i].approvedOperator(
          address(asset_), address(asset_), address(s.properties.debtAsset)
        ),
        type(uint256).max
      );
      unchecked {
        ++i;
      }
    }
    s.extAddresses.providers = providers;

    emit ProvidersChanged(providers);
  }
}
