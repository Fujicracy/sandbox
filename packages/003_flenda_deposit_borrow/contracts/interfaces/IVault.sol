// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

/**
 * @title Vault interface.
 * @author fujidao Labs
 * @notice  Defines the interface for vault operations extending from IERC4326.
 */

import "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IVault is IERC4626 {

  /**
  * @dev Returns the address of the debt underlying token used for the Vault for borrowing and payback accounting.
  *
  * - MUST be an ERC-20 token contract.
  * - MUST NOT revert.
  */
  function debtAsset() external view returns (address);

  /**
  * @dev Mints debtShares to onBehalf by taking a loan of exact amount of underlying tokens.
  *
  * - MUST emit the Borrow event.
  * - MUST revert if owner does not own sufficient collateral to back debt.
  * - MUST revert if caller is not onBehalf or permission to act onBehalf.
  *
  */
  function borrow(uint256 debt, address receiver, address owner) external returns (uint256);

  /**
  * @dev burns debtShares to onBehalf by paying back loan with exact amount of underlying tokens.
  *
  * - MUST emit the Payback event.
  *
  * NOTE: most implementations will require pre-erc20-approval of the underlying asset token.
  */
  function payback(uint256 debt, address owner) external returns (uint256);
}