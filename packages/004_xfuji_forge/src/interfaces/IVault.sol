// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

/**
 * @title Vault Interface.
 * @author Fujidao Labs
 * @notice Defines the interface for vault operations extending from IERC4326.
 */

import "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import "./ILendingProvider.sol";

interface IVault is IERC4626 {
  function debtAsset() external view returns (address);

  /**
   * @dev Mints debtShares to owner by taking a loan of exact amount of underlying tokens.
   *
   * - MUST emit the Borrow event.
   * - MUST revert if owner does not own sufficient collateral to back debt.
   * - MUST revert if caller is not owner or permission to act owner.
   *
   */
  function borrow(
    uint256 debt,
    address receiver,
    address owner
  ) external returns (uint256);

  /**
   * @dev burns debtShares to owner by paying back loan with exact amount of underlying tokens.
   *
   * - MUST emit the Payback event.
   *
   * NOTE: most implementations will require pre-erc20-approval of the underlying asset token.
   */
  function payback(uint256 debt, address receiver) external returns (uint256);

  function setActiveProvider(ILendingProvider activeProvider) external;
}
