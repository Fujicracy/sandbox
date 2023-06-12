// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {
  AppStorage,
  VaultPropertyStorage,
  VaultAccountingStorage,
  VaultExtAddrStorage,
  VaultSecurityStorage
} from "./../../libraries/LibVaultStorage.sol";
import {SystemAccessControl} from "../../access/SystemAccessControl.sol";
import {IVaultPausable, VaultActions} from "./../../interfaces/IVaultPausable.sol";

contract VaultBase is IVaultPausable, SystemAccessControl {
  AppStorage internal s;

  /// @dev Custom Errors
  error VaultBase__requiredNotPaused_actionPaused();
  error VaultBase__requiredPaused_actionNotPaused();

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
  function paused(VaultActions action) public view override returns (bool) {
    return s.security.actionsPaused[action];
  }

  /// @inheritdoc IVaultPausable
  function pauseForceAll() external override hasRole(s.extAddresses.chief, msg.sender, PAUSER_ROLE) {
    _pauseForceAllActions();
  }

  /// @inheritdoc IVaultPausable
  function unpauseForceAll()
    external
    override
    hasRole(s.extAddresses.chief, msg.sender, UNPAUSER_ROLE)
  {
    _unpauseForceAllActions();
  }

  /// @inheritdoc IVaultPausable
  function pause(VaultActions action)
    external
    virtual
    override
    hasRole(s.extAddresses.chief, msg.sender, PAUSER_ROLE)
  {
    _pause(action);
  }

  /// @inheritdoc IVaultPausable
  function unpause(VaultActions action)
    external
    virtual
    override
    hasRole(s.extAddresses.chief, msg.sender, UNPAUSER_ROLE)
  {
    _unpause(action);
  }

  /**
   * @dev Throws if the `action` in contract is paused.
   *
   * @param action Enum: 0-deposit, 1-withdraw, 2-borrow, 3-payback
   */
  function _requireNotPaused(VaultActions action) private view {
    if (s.security.actionsPaused[action]) {
      revert VaultBase__requiredNotPaused_actionPaused();
    }
  }

  /**
   * @dev Throws if the `action` in contract is not paused.
   *
   * @param action Enum: 0-deposit, 1-withdraw, 2-borrow, 3-payback
   */
  function _requirePaused(VaultActions action) private view {
    if (!s.security.actionsPaused[action]) {
      revert VaultBase__requiredPaused_actionNotPaused();
    }
  }

  /**
   * @dev Sets pause state for `action` of this vault.
   *
   * @param action Enum: 0-deposit, 1-withdraw, 2-borrow, 3-payback
   */
  function _pause(VaultActions action) internal whenNotPaused(action) {
    s.security.actionsPaused[action] = true;
    emit Paused(msg.sender, action);
  }

  /**
   * @dev Sets unpause state for `action` of this vault.
   *
   * @param action Enum: 0-deposit, 1-withdraw, 2-borrow, 3-payback
   */
  function _unpause(VaultActions action) internal whenPaused(action) {
    s.security.actionsPaused[action] = false;
    emit Unpaused(msg.sender, action);
  }

  /**
   * @dev Forces set paused state for all `VaultActions`.
   */
  function _pauseForceAllActions() internal {
    s.security.actionsPaused[VaultActions.Deposit] = true;
    s.security.actionsPaused[VaultActions.Withdraw] = true;
    s.security.actionsPaused[VaultActions.Borrow] = true;
    s.security.actionsPaused[VaultActions.Payback] = true;
    emit PausedForceAll(msg.sender);
  }

  /**
   * @dev Forces set unpause state for all `VaultActions`.
   */
  function _unpauseForceAllActions() internal {
    s.security.actionsPaused[VaultActions.Deposit] = false;
    s.security.actionsPaused[VaultActions.Withdraw] = false;
    s.security.actionsPaused[VaultActions.Borrow] = false;
    s.security.actionsPaused[VaultActions.Payback] = false;
    emit UnpausedForceAll(msg.sender);
  }
}
