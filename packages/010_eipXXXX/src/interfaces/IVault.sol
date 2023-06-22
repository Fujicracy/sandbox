// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {IERC20Metadata} from "./IERC20Metadata.sol";
import {IERC4626} from "./IERC4626.sol";
import {IERC4627} from "./IERC4627.sol";

interface IVault is IERC4626, IERC4627, IERC20Metadata {
  /**
   * @notice Returns the amount of assets owned by `owner`.
   *
   * @param owner to check balance
   *
   * @dev This method avoids having to do external conversions from shares to
   * assets, since {IERC4626-balanceOf} returns shares.
   */
  function balanceOfAsset(address owner) external view returns (uint256 assets);

  /**
   * @notice Returns the current amount of withdraw allowance from `owner` to `receiver`
   * that can be executed by `operator`. This is similar to {IERC20-allowance};
   * however, the `operator` can be explicitly passed.
   *
   * @param owner who provides allowance
   * @param operator who can execute the use of the allowance
   * @param receiver who can spend the allowance
   */
  function withdrawAllowance(
    address owner,
    address operator,
    address receiver
  )
    external
    view
    returns (uint256);

  /**
   * @notice Returns the current amount of borrow allowance from `owner` to `receiver` that
   * can be executed by `operator`. This is similar to {IERC20-allowance} for
   * BaseVault-debtAsset.
   *
   * @param owner who provides allowance
   * @param operator who can execute the use of the allowance
   * @param receiver who can spend the allowance
   */
  function borrowAllowance(
    address owner,
    address operator,
    address receiver
  )
    external
    view
    returns (uint256);

  /**
   * @dev Atomically increases the `withdrawAllowance` granted to `receiver` and
   * executable by `operator` by the caller.
   * Based on OZ {ERC20-increaseAllowance} for assets.
   *
   * @param operator who can execute the use of the allowance
   * @param receiver who can spend the allowance
   * @param byAmount to increase withdraw allowance
   *
   * @dev Requirements:
   * - Must emit a {WithdrawApproval} event indicating the updated withdraw allowance.
   * - Must check `operator` and `receiver are not zero address.
   */
  function increaseWithdrawAllowance(
    address operator,
    address receiver,
    uint256 byAmount
  )
    external
    returns (bool);

  /**
   * @dev Atomically decreases the `withdrawAllowance` granted to `receiver` and
   * executable by `operator` by the caller.
   * Based on OZ {ERC20-decreaseAllowance} for assets.
   *
   * @param operator who can execute the use of the allowance
   * @param receiver who can spend the allowance
   * @param byAmount to decrease withdraw allowance
   *
   * @dev Requirements:
   * - Must emit a {WithdrawApproval} event indicating the updated withdraw allowance.
   * - Must check `operator` and `receiver` are not zero address.
   * - Must check `operator` and `receiver` have `borrowAllowance` of at least `byAmount`.
   *
   */
  function decreaseWithdrawAllowance(
    address operator,
    address receiver,
    uint256 byAmount
  )
    external
    returns (bool);
}
