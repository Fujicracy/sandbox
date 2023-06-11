// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {AppStorage, LibVaultLogic} from "./../../libraries/LibVaultStorage.sol";
import {VaultPausable} from "./VaultPausable.sol";
import {VaultActions} from "./../../interfaces/IVaultPausable.sol";
import {Rounding} from "./../../libraries/openzeppelin/Math.sol";
import {IERC4626} from "../../interfaces/IERC4626.sol";
import {IERC20Metadata} from "../../interfaces/IERC20Metadata.sol";

contract VaultAssets is VaultPausable, IERC4626, IERC20Metadata {
  ///@dev Custom errors
  error AssetManagement__checkAddresNotZero_invalidInput();
  error AssetManagement__tranfer_amountExceedsBalance();

  /**
   * @dev Returns the address of the underlying token used for the Vault
   * for accounting, depositing, and withdrawing.
   */
  function asset() public view override returns (address) {
    return address(s.asset);
  }

  /**
   * @dev Returns the decimals places of the asset shares.
   */
  function decimals() public view returns (uint8) {
    return s.assetDecimals;
  }

  /**
   * @notice Returns the amount of asset shares owned by `owner`.
   *
   * @param owner to check balance
   */
  function balanceOf(address owner) public view override returns (uint256 shares) {
    return s.assetShareBalances[owner];
  }

  /**
   * @notice Returns the total supply of asset shares in this vault.
   */
  function totalSupply() public view override returns (uint256) {
    return s.totalAssetShareSupply;
  }

  function transfer(address to, uint256 amount) public override returns (bool) {
    address owner = msg.sender;
    _transfer(owner, to, amount);
    return true;
  }

  /**
   * @notice Returns the amount of assets owned by `owner`.
   *
   * @param owner to check balance
   *
   * @dev This method avoids having to do external conversions from shares to
   * assets, since {IERC4626-balanceOf} returns shares.
   */
  function balanceOfAsset(address owner) public view override returns (uint256 assets) {
    return convertToAssets(s.assetShareBalances[owner]);
  }

  /// @inheritdoc IERC4626
  function totalAssets() public view virtual override returns (uint256 assets) {
    return LibVaultLogic._checkProvidersBalance("getDepositBalance", s.providers);
  }

  /// @inheritdoc IERC4626
  function convertToShares(uint256 assets) public view virtual override returns (uint256 shares) {
    return
      LibVaultLogic._convertToShares(assets, totalAssets(), s.totalAssetShareSupply, Rounding.Down);
  }

  /// @inheritdoc IERC4626
  function convertToAssets(uint256 shares) public view virtual override returns (uint256 assets) {
    return
      LibVaultLogic._convertToAssets(shares, totalAssets(), s.totalAssetShareSupply, Rounding.Down);
  }

  /// @inheritdoc IERC4626
  function maxDeposit(address) public view virtual override returns (uint256) {
    if (paused(VaultActions.Deposit)) {
      return 0;
    }
    return type(uint256).max;
  }

  /// @inheritdoc IERC4626
  function maxMint(address) public view virtual override returns (uint256) {
    if (paused(VaultActions.Deposit)) {
      return 0;
    }
    return type(uint256).max;
  }

  /// @inheritdoc IERC4626
  function maxWithdraw(address owner) public view override returns (uint256) {
    if (paused(VaultActions.Withdraw)) {
      return 0;
    }
    return _computeFreeAssets(owner);
  }

  /// @inheritdoc IERC4626
  function maxRedeem(address owner) public view override returns (uint256) {
    if (paused(VaultActions.Withdraw)) {
      return 0;
    }
    return convertToShares(maxWithdraw(owner));
  }

  /// @inheritdoc IERC4626
  function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
    return _previewDeposit(assets, totalAssets());
  }

  /// @inheritdoc IERC4626
  function previewMint(uint256 shares) public view virtual override returns (uint256) {
    return _previewMint(shares, totalAssets());
  }

  /// @inheritdoc IERC4626
  function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
    return _previewWithdraw(assets, totalAssets());
  }

  /// @inheritdoc IERC4626
  function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
    return _previewRedeem(shares, totalAssets());
  }

  /// @dev Private version of {IERC4626-previewDeposit} does not call `totalAssets()`
  function _previewDeposit(uint256 assets, uint256 totalAssets_) private view returns (uint256) {
    return
      LibVaultLogic._convertToShares(assets, totalAssets_, s.totalAssetShareSupply, Rounding.Down);
  }

  /// @dev Private version of {IERC4626-previewMint} does not call `totalAssets()`
  function _previewMint(uint256 shares, uint256 totalAssets_) private view returns (uint256) {
    return
      LibVaultLogic._convertToAssets(shares, totalAssets_, s.totalAssetShareSupply, Rounding.Up);
  }

  /// @dev Private version of {IERC4626-previewWithdraw} does not call `totalAssets()`
  function _previewWithdraw(uint256 assets, uint256 totalAssets_) private view returns (uint256) {
    return
      LibVaultLogic._convertToShares(assets, totalAssets_, s.totalAssetShareSupply, Rounding.Up);
  }

  /// @dev Private version of {IERC4626-previewRedeem} does not call `totalAssets()`
  function _previewRedeem(uint256 shares, uint256 totalAssets_) private view returns (uint256) {
    return
      LibVaultLogic._convertToAssets(shares, totalAssets_, s.totalAssetShareSupply, Rounding.Down);
  }

  /**
   * @dev Moves `amount` of tokens from `from` to `to`.
   *
   * This internal function is equivalent to {transfer}, and can be used to
   * e.g. implement automatic token fees, slashing mechanisms, etc.
   *
   * Emits a {Transfer} event.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `from` must have a balance of at least `amount`.
   */
  function _transfer(address from, address to, uint256 amount) internal virtual {
    _checkAddressNotZero(from);
    _checkAddressNotZero(to);

    _beforeTokenTransfer(from, to, amount);

    uint256 fromBalance = s.assetShareBalances[from];
    // uint256 fromBalance = _balances[from];
    if (amount > fromBalance) {
      revert AssetManagement__tranfer_amountExceedsBalance();
    }
    unchecked {
      s.assetShareBalances[from] = fromBalance - amount;
      // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
      // decrementing then incrementing.
      s.assetShareBalances[to] += amount;
    }

    emit Transfer(from, to, amount);

    _afterTokenTransfer(from, to, amount);
  }

  /**
   * @dev Hook that is called before any transfer of tokens. This includes
   * minting and burning.
   *
   * Calling conditions:
   *
   * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
   * will be transferred to `to`.
   * - when `from` is zero, `amount` tokens will be minted for `to`.
   * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
   * - `from` and `to` are never both zero.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

  /**
   * @dev Hook that is called after any transfer of tokens. This includes
   * minting and burning.
   *
   * Calling conditions:
   *
   * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
   * has been transferred to `to`.
   * - when `from` is zero, `amount` tokens have been minted for `to`.
   * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
   * - `from` and `to` are never both zero.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}

  function _checkAddressNotZero(address addr) internal pure {
    if (addr == address(0)) {
      revert AssetManagement__checkAddresNotZero_invalidInput();
    }
  }
}
