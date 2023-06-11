// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

/**
 * @dev Interface of EIP-4627 extension to "Tokenized Vault Standard", adding
 * capability to an EIP-4626 Vault to handle debt in the form of "deb shares".
 *
 */
interface IERC4627 { /*is IERC4626*/
  /**
   * @dev Emit when borrow action occurs.
   *
   * @param sender who calls {IERC4627-borrow}
   * @param receiver of the borrowed 'debt' amount
   * @param owner who will incur the debt
   * @param debt amount
   * @param shares amount of 'debtShares' received
   */
  event Borrow(
    address indexed sender,
    address indexed receiver,
    address indexed owner,
    uint256 debt,
    uint256 shares
  );

  /**
   * @dev Emit when payback action occurs.
   *
   * @param sender address who calls {IERC4627-payback}
   * @param owner address whose debt will be reduced
   * @param debt amount
   * @param shares amound of 'debtShares' burned
   */
  event Payback(address indexed sender, address indexed owner, uint256 debt, uint256 shares);

  /**
   * @notice Returns the address of the underlying token used as debt in functions
   * `borrow()`, and `payback()`. Based on {IERC4626-asset}.
   *
   * @dev Requirements:
   * - Must be an ERC-20 token contract.
   * - Must not revert.
   * - Must return zero in a {YieldVault}.
   */
  function debtAsset() external view returns (address);

  /**
   * @notice Returns the total amount of the underlying debt asset
   * that is “managed” by this vault. Based on {IERC4626-totalAssets}.
   *
   * @dev Requirements:
   * - Must account for any compounding occuring from yield or interest accrual.
   * - Must be inclusive of any fees that are charged against assets in the Vault.
   * - Must not revert.
   * - Must return zero in a {YieldVault}.
   */
  function totalDebt() external view returns (uint256);

  /**
   * @notice Returns the amount of shares this vault would exchange for the amount
   * of debt assets provided. Based on {IERC4626-convertToShares}.
   *
   * @param debt to convert into `debtShares`
   *
   * @dev Requirements:
   * - Must not be inclusive of any fees that are charged against assets in the Vault.
   * - Must not show any variations depending on the caller.
   * - Must not reflect slippage or other on-chain conditions, when performing the actual exchange.
   * - Must not revert.
   *
   * NOTE: This calculation MAY not reflect the “per-user” price-per-share, and instead Must reflect the
   * “average-user’s” price-per-share, meaning what the average user Must expect to see when exchanging to and
   * from.
   */
  function convertDebtToShares(uint256 debt) external view returns (uint256 shares);

  /**
   * @notice Returns the amount of debt assets that this vault would exchange for the amount
   * of `debtShares` provided. Based on {IERC4626-convertToAssets}.
   *
   * @param shares amount to convert into `debt`
   *
   * @dev Requirements:
   * - Must not be inclusive of any fees that are charged against assets in the Vault.
   * - Must not show any variations depending on the caller.
   * - Must not reflect slippage or other on-chain conditions, when performing the actual exchange.
   * - Must not revert.
   *
   * NOTE: This calculation MAY not reflect the “per-user” price-per-share, and instead must reflect the
   * “average-user’s” price-per-share, meaning what the average user Must expect to see when exchanging to and
   * from.
   */
  function convertToDebt(uint256 shares) external view returns (uint256 debt);

  /**
   * @notice Returns the maximum amount of debt that can be payback by the `borrower`.
   *
   * @param owner to check
   *
   * @dev Requirements:
   * - Must not revert.
   */
  function maxPayback(address owner) external view returns (uint256 debt);

  /**
   * @notice Returns the amount of `debtShares` that will be burned by paying back
   * `debt` amount.
   *
   * @param debt to check
   *
   * @dev Requirements:
   * - Must not revert.
   */
  function previewPayback(uint256 debt) external view returns (uint256 shares);

  /**
   * @notice Burns `debtShares` to `receiver` by paying back loan with exact amount of underlying tokens.
   *
   * @param debt amount to payback
   * @param receiver to whom debt amount is being paid back
   *
   * @dev Implementations will require pre-erc20-approval of the underlying debt token.
   * Requirements:
   * - Must emit a Payback event.
   */
  function payback(uint256 debt, address receiver) external returns (uint256 shares);

  /**
   * @notice Returns the maximum amount of debt shares that can be "burned-for-payback" by the `borrower`.
   *
   * @param owner to check
   *
   * @dev Requirements:
   * - Must not revert.
   */
  function maxBurnDebt(address owner) external view returns (uint256 shares);

  /**
   * @notice Returns the amount of debt asset that will be pulled from user, if `debtShares` are
   * burned to payback.
   *
   * @param debt to check
   *
   * @dev Requirements:
   * - Must not revert.
   */
  function previewBurnDebt(uint256 shares) external view returns (uint256 debt);

  /**
   * @notice Burns `debtShares` to `owner` by paying back loan by specifying debt shares.
   *
   * @param shares of debt to payback
   * @param owner to whom debt amount is being paid back
   *
   * @dev Implementations will require pre-erc20-approval of the underlying debt token.
   * Requirements:
   * - Must emit a Payback event.
   */
  function burnDebt(uint256 shares, address owner) external returns (uint256 debt);

  /**
   * @notice Returns the maximum amount of the debt asset that can be borrowed for the `owner`,
   * through a borrow call.
   *
   * @param owner to check
   *
   * @dev Requirements:
   * - Must return a limited value if receiver is subject to some borrow limit.
   * - Must return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be borrowed.
   * - Must not revert.
   */
  function maxBorrow(address owner) external view returns (uint256 debt);

  /**
   * @notice Returns the amount of `debtShares` that borrowing `debt` amount will generate.
   *
   * @param debt amount to check
   *
   * @dev Requirements:
   * - Must not revert.
   */
  function previewBorrow(uint256 debt) external view returns (uint256 shares);

  /**
   * @notice Perform a borrow action. Function inspired on {IERC4626-deposit}.
   *
   * @param debt amount
   * @param receiver of the `debt` amount
   * @param owner who will incur the `debt` amount
   *
   * * @dev Mints debtShares to owner by taking a loan of exact amount of underlying tokens.
   * Requirements:
   * - Must emit the Borrow event.
   * - Must revert if owner does not own sufficient collateral to back debt.
   * - Must revert if caller is not owner or permissioned operator to act on owner behalf.
   */
  function borrow(uint256 debt, address receiver, address owner) external returns (uint256 shares);

  /**
   * @notice Returns the maximum amount of debt shares that can be "minted-for-borrowing" by the `borrower`.
   *
   * @param owner to check
   *
   * @dev Requirements:
   * - Must not revert.
   */
  function maxMintDebt(address owner) external view returns (uint256 shares);

  /**
   * @notice Returns the amount of debt that minting `debtShares` amount will generate.
   *
   * @param shares of debt to check
   *
   * @dev Requirements:
   * - Must not revert.
   */
  function previewMintDebt(uint256 shares) external view returns (uint256 debt);

  /**
   * @notice Perform a borrow action by minting `debtShares`.
   *
   * @param shares of debt to mint
   * @param receiver of the borrowed amount
   * @param owner who will incur the `debt` and whom `debtShares` will be accounted
   *
   * * @dev Mints `debtShares` to `owner`.
   * Requirements:
   * - Must emit the Borrow event.
   * - Must revert if owner does not own sufficient collateral to back debt.
   * - Must revert if caller is not owner or permissioned operator to act on owner behalf.
   */
  function mintDebt(
    uint256 shares,
    address receiver,
    address owner
  )
    external
    returns (uint256 debt);
}
