// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

/**
 * @title SystemAccessControl
 *
 * @author Fujidao Labs
 *
 * @notice Abstract contract that should be inherited by contract implementations that
 * call the {Chief} contract for access control checks.
 */

import {IChief} from "../interfaces/IChief.sol";
import {CoreRoles} from "./CoreRoles.sol";

contract SystemAccessControl is CoreRoles {
  /// @dev Custom Errors
  error SystemAccessControl__hasRole_missingRole(address caller, bytes32 role);
  error SystemAccessControl__onlyTimelock_callerIsNotTimelock();
  error SystemAccessControl__onlyHouseKeeper_notHouseKeeper();

  /**
   * @dev Modifier that checks `caller` has `role`.
   */
  modifier hasRole(IChief chief, address caller, bytes32 role) {
    if (!chief.hasRole(role, caller)) {
      revert SystemAccessControl__hasRole_missingRole(caller, role);
    }
    _;
  }

  /**
   * @dev Modifier that checks `msg.sender` has HOUSE_KEEPER_ROLE.
   */
  modifier onlyHouseKeeper(IChief chief) {
    if (!chief.hasRole(HOUSE_KEEPER_ROLE, msg.sender)) {
      revert SystemAccessControl__onlyHouseKeeper_notHouseKeeper();
    }
    _;
  }

  /**
   * @dev Modifier that checks `msg.sender` is the defined `timelock` in {Chief}
   * contract.
   */
  modifier onlyTimelock(IChief chief) {
    if (msg.sender != chief.timelock()) {
      revert SystemAccessControl__onlyTimelock_callerIsNotTimelock();
    }
    _;
  }
}