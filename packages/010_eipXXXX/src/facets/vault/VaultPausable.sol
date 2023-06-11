// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

/**
 * @title VaultPausable
 *
 * @author Fujidao Labs
 *
 * @notice Abstract pausable contract developed for granular control over vault actions.
 * This contract should be inherited by a vault implementation. The code is inspired on
 * OpenZeppelin-Pausable contract.
 */

import {AppStorage} from "./../../libraries/LibVaultStorage.sol";
import {IVaultPausable, VaultActions} from "./../../interfaces/IVaultPausable.sol";

abstract contract VaultPausable is IVaultPausable {
  AppStorage internal s;

  /// @dev Custom Errors
  error PausableVault__requiredNotPaused_actionPaused();
  error PausableVault__requiredPaused_actionNotPaused();

  /**
   * @dev Modifier to make a function callable only when `VaultAction` in the contract
   * is not paused.
   */
  modifier whenNotPaused(VaultActions action) {
    _requireNotPaused(action);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when `VaultAction` in the contract
   * is paused.
   */
  modifier whenPaused(VaultActions action) {
    _requirePaused(action);
    _;
  }

  /// @inheritdoc IVaultPausable
  function paused(VaultActions action) public view virtual returns (bool) {
    return s.actionsPaused[action];
  }

  /// @inheritdoc IVaultPausable
  function pauseForceAll() external virtual override;

  /// @inheritdoc IVaultPausable
  function unpauseForceAll() external virtual override;

  /// @inheritdoc IVaultPausable
  function pause(VaultActions action) external virtual override;

  /// @inheritdoc IVaultPausable
  function unpause(VaultActions action) external virtual override;

  /**
   * @dev Throws if the `action` in contract is paused.
   *
   * @param action Enum: 0-deposit, 1-withdraw, 2-borrow, 3-payback
   */
  function _requireNotPaused(VaultActions action) private view {
    if (s.actionsPaused[action]) {
      revert PausableVault__requiredNotPaused_actionPaused();
    }
  }

  /**
   * @dev Throws if the `action` in contract is not paused.
   *
   * @param action Enum: 0-deposit, 1-withdraw, 2-borrow, 3-payback
   */
  function _requirePaused(VaultActions action) private view {
    if (!s.actionsPaused[action]) {
      revert PausableVault__requiredPaused_actionNotPaused();
    }
  }

  /**
   * @dev Sets pause state for `action` of this vault.
   *
   * @param action Enum: 0-deposit, 1-withdraw, 2-borrow, 3-payback
   */
  function _pause(VaultActions action) internal whenNotPaused(action) {
    s.actionsPaused[action] = true;
    emit Paused(msg.sender, action);
  }

  /**
   * @dev Sets unpause state for `action` of this vault.
   *
   * @param action Enum: 0-deposit, 1-withdraw, 2-borrow, 3-payback
   */
  function _unpause(VaultActions action) internal whenPaused(action) {
    s.actionsPaused[action] = false;
    emit Unpaused(msg.sender, action);
  }

  /**
   * @dev Forces set paused state for all `VaultActions`.
   */
  function _pauseForceAllActions() internal {
    s.actionsPaused[VaultActions.Deposit] = true;
    s.actionsPaused[VaultActions.Withdraw] = true;
    s.actionsPaused[VaultActions.Borrow] = true;
    s.actionsPaused[VaultActions.Payback] = true;
    emit PausedForceAll(msg.sender);
  }

  /**
   * @dev Forces set unpause state for all `VaultActions`.
   */
  function _unpauseForceAllActions() internal {
    s.actionsPaused[VaultActions.Deposit] = false;
    s.actionsPaused[VaultActions.Withdraw] = false;
    s.actionsPaused[VaultActions.Borrow] = false;
    s.actionsPaused[VaultActions.Payback] = false;
    emit UnpausedForceAll(msg.sender);
  }
}
