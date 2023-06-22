// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {AppStorage, LibVaultLogic} from "./../../libraries/LibVaultStorage.sol";
import {VaultBase} from "./VaultBase.sol";
import {IVault} from "../../interfaces/IVault.sol";
import {VaultActions} from "../../interfaces/IVaultPausable.sol";
import {Rounding} from "../../libraries/openzeppelin/Math.sol";
import {IERC4626} from "../../interfaces/IERC4626.sol";
import {IERC20Metadata} from "../../interfaces/IERC20Metadata.sol";
import {SafeERC20} from "../../libraries/openzeppelin/SafeERC20.sol";

contract VaultAssets is IERC4626, IERC20Metadata, VaultBase {
  /**
   * @dev Emitted when `asset` withdraw allowance is set.
   *
   * @param owner who provides allowance
   * @param operator who can execute the use of the allowance
   * @param receiver who can spend the allowance
   * @param amount of allowance given
   */
  event WithdrawApproval(address indexed owner, address operator, address receiver, uint256 amount);

  ///@dev Custom errors
  error VaultAssets__checkAddresNotZero_invalidInput();
  error VaultAssets__checkAmountIsNotZero_invalidInput();
  error VaultAssets__insufficientWithdrawAllowance();
  error VaultAssets__allowanceBelowZero();
  error VaultAssets__tranfer_amountExceedsBalance();
  error VaultAssets__beforeTokenTransfer_moreThanMax();
  error VaultAssets__deposit_slippageTooHigh();
  error VaultAssets__deposit_lessThanMin();
  error VaultAssets__mint_slippageTooHigh();
  error VaultAssets__withdraw_slippageTooHigh();
  error VaultAssets__withdraw_moreThanMax();
  error VaultAssets__redeem_slippageTooHigh();
  error ERC20__burn_amountExceedsBalance();

  /**
   * @dev Returns the name of this vault.
   */
  function name() public view override returns (string memory) {
    return s.properties.vaultName;
  }

  /**
   * @dev Returns the symbol of the tokenized share token.
   */
  function symbol() public view override returns (string memory) {
    return s.properties.vaultSymbol;
  }

  /**
   * @dev Returns the address of the underlying token used for the Vault
   * for accounting, depositing, and withdrawing.
   */
  function asset() public view override returns (address) {
    return address(s.properties.asset);
  }

  /**
   * @dev Returns the decimals places of the asset shares.
   */
  function decimals() public view returns (uint8) {
    return s.properties.assetDecimals;
  }

  /**
   * @notice Returns the amount of asset shares owned by `owner`.
   *
   * @param owner to check balance
   */
  function balanceOf(address owner) public view override returns (uint256 shares) {
    return s.accounting.assetShareBalances[owner];
  }

  /**
   * @notice Returns the total supply of asset shares in this vault.
   */
  function totalSupply() public view override returns (uint256) {
    return s.accounting.totalAssetShareSupply;
  }

  /**
   * @notice Moves `amount` asset shares from the caller's account to `to`.
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * @param to whom to send shares
   * @param amount of shares
   *
   * @dev
   * Requirements
   * - Must emit a {IERC20-Transfer} event.
   */
  function transfer(address to, uint256 amount) public override returns (bool) {
    address owner = msg.sender;
    _transfer(owner, to, amount);
    return true;
  }

  /**
   * @dev Moves `amount` shares from `from` to `to` using the
   * allowance mechanism. `amount` is then deducted from the caller's
   * `withdrawAllowance`. Assumes `msg.sender` == operator.
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * @dev Requirements:
   * - Must emit an {IERC20-Transfer} event.
   */
  function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
    address operator = msg.sender;
    _spendWithdrawAllowance(from, operator, to, amount);
    _transfer(from, to, amount);
    return true;
  }

  /**
   * @notice Returns the remaining number of asset shares that `spender/operator` will be
   * allowed to transfer on behalf of `owner` through {transferFrom}. This is
   * zero by default. In this vault context it is assumed: spender == operator == receiver.
   *
   * @param owner of the allowance
   * @param spender or operator of the allowance
   *
   * @dev Requirements:
   * - Must handles share `allowance` using {AppStorage.withdrawAllowance}.
   * - Must assume `spender` and `operator` are the same.
   */
  function allowance(address owner, address spender) public view override returns (uint256) {
    return s.accounting.withdrawAllowance[owner][spender][spender];
  }

  /**
   * @notice Returns the current amount of withdraw allowance from `owner` to `receiver` that
   * can be executed by `operator`. This is similar to {IERC20-allowance}; however, the `operator`
   * can be explicitly passed.
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
    public
    view
    returns (uint256)
  {
    return s.accounting.withdrawAllowance[owner][operator][receiver];
  }

  /**
   * @notice Sets `amount` as the allowance of `spender/operator` over the caller's asset shares.
   * Returns a boolean value indicating whether the operation succeeded.
   * It assumes spender == operator ==  receiver.
   * Otherwise use {IVaultPermissions-increaseWithdrawAllowance()}
   *
   * IMPORTANT: Beware that changing an allowance with this method brings the risk
   * that someone may use both the old and the new allowance by unfortunate
   * transaction ordering. One possible solution to mitigate this race
   * condition is to first reduce the spender's allowance to 0 and set the
   * desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   *
   * @dev Requirements
   * - Must emits an {IERC20-Approval} event.
   * - Must check non-zero inputs.
   */
  function approve(address spender, uint256 amount) external returns (bool) {
    address owner = msg.sender;

    _checkAddressNotZero(owner);
    _checkAddressNotZero(spender);
    _checkAmountIsNotZero(amount);

    s.accounting.withdrawAllowance[owner][spender][spender] = amount;

    emit Approval(owner, spender, amount);
    return true;
  }

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
    public
    returns (bool)
  {
    address owner = msg.sender;
    _setWithdrawAllowance(
      owner,
      operator,
      receiver,
      s.accounting.withdrawAllowance[owner][operator][receiver] + byAmount
    );
    return true;
  }

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
    public
    returns (bool)
  {
    address owner = msg.sender;
    uint256 currentAllowance = s.accounting.withdrawAllowance[owner][operator][receiver];
    if (byAmount > currentAllowance) {
      revert VaultAssets__allowanceBelowZero();
    }
    unchecked {
      _setWithdrawAllowance(owner, operator, receiver, currentAllowance - byAmount);
    }
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
  function balanceOfAsset(address owner) public view returns (uint256 assets) {
    return convertToAssets(s.accounting.assetShareBalances[owner]);
  }

  /// @inheritdoc IERC4626
  function totalAssets() public view virtual override returns (uint256 assets) {
    return LibVaultLogic._checkProvidersBalance("getDepositBalance", s.extAddresses.providers);
  }

  /// @inheritdoc IERC4626
  function convertToShares(uint256 assets) public view virtual override returns (uint256 shares) {
    return LibVaultLogic._convertToShares(
      assets, totalAssets(), s.accounting.totalAssetShareSupply, Rounding.Down
    );
  }

  /// @inheritdoc IERC4626
  function convertToAssets(uint256 shares) public view virtual override returns (uint256 assets) {
    return LibVaultLogic._convertToAssets(
      shares, totalAssets(), s.accounting.totalAssetShareSupply, Rounding.Down
    );
  }

  /// @inheritdoc IERC4626
  function maxDeposit(address) public view virtual override returns (uint256) {
    if (paused(VaultActions.Deposit)) {
      return 0;
    }
    return type(uint256).max;
  }

  /**
   * @notice Slippage protected `deposit()` per EIP5143.
   *
   * @param assets amount to be deposited
   * @param receiver to whom `assets` amount will be credited
   * @param minShares amount expected from this deposit action
   *
   * @dev Refer to https://eips.ethereum.org/EIPS/eip-5143.
   * Requirements:
   * - Must mint at least `minShares` when calling `deposit()`.
   */
  function deposit(uint256 assets, address receiver, uint256 minShares) public returns (uint256) {
    uint256 receivedShares = deposit(assets, receiver);
    if (receivedShares < minShares) {
      revert VaultAssets__deposit_slippageTooHigh();
    }
    return receivedShares;
  }

  /// @inheritdoc IERC4626
  function deposit(uint256 assets, address receiver) public override returns (uint256) {
    address caller = msg.sender;
    uint256 totalAssets_ = totalAssets();
    // Gas saving calling `_previewDeposit` withdout having to call again `totalAssets`.
    uint256 shares = _previewDeposit(assets, totalAssets_);

    _depositChecks(caller, receiver, assets, shares);
    _deposit(caller, receiver, assets, shares);

    return shares;
  }

  /// @inheritdoc IERC4626
  function maxMint(address) public view virtual override returns (uint256) {
    if (paused(VaultActions.Deposit)) {
      return 0;
    }
    return type(uint256).max;
  }

  /**
   * @notice Slippage protected `mint()` per EIP5143.
   *
   * @param shares amount to mint
   * @param receiver to whom `shares` amount will be credited
   * @param maxAssets amount that must be credited when calling mint
   *
   * @dev Refer to https://eips.ethereum.org/EIPS/eip-5143.
   * Requirements:
   * - Must not pull more than `maxAssets` when calling `mint()`.
   */
  function mint(
    uint256 shares,
    address receiver,
    uint256 maxAssets
  )
    public
    virtual
    returns (uint256)
  {
    uint256 pulledAssets = mint(shares, receiver);
    if (pulledAssets > maxAssets) {
      revert VaultAssets__mint_slippageTooHigh();
    }
    return pulledAssets;
  }

  /// @inheritdoc IERC4626
  function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
    address caller = msg.sender;
    uint256 totalAssets_ = totalAssets();
    // Gas saving to do `PreviewMint` withdout having to call again `totalAssets`.
    uint256 assets = _previewMint(shares, totalAssets_);

    _depositChecks(caller, receiver, assets, shares);
    _deposit(caller, receiver, assets, shares);

    return assets;
  }

  /// @inheritdoc IERC4626
  function maxWithdraw(address owner) public view override returns (uint256) {
    return _maxWithdraw(owner, totalAssets(), false);
  }

  /**
   * @notice Slippage protected `withdraw()` per EIP5143.
   *
   * @param assets amount that is being withdrawn
   * @param receiver to whom `assets` amount will be transferred
   * @param owner to whom `assets` amount will be debited
   * @param maxShares amount that shall be burned when calling withdraw
   *
   * @dev Refer to https://eips.ethereum.org/EIPS/eip-5143.
   * Requirements:
   * - Must not burn more than `maxShares` when calling `withdraw()`.
   */
  function withdraw(
    uint256 assets,
    address receiver,
    address owner,
    uint256 maxShares
  )
    public
    virtual
    returns (uint256)
  {
    uint256 burnedShares = withdraw(assets, receiver, owner);
    if (burnedShares > maxShares) {
      revert VaultAssets__withdraw_slippageTooHigh();
    }
    return burnedShares;
  }

  /// @inheritdoc IERC4626
  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  )
    public
    override
    returns (uint256)
  {
    address caller = msg.sender;
    uint256 totalAssets_ = totalAssets();
    // Gas saving `PreviewWithdraw` without having to call again `totalAssets()`.
    uint256 shares = _previewWithdraw(assets, totalAssets_);

    _withdrawChecks(caller, receiver, owner, assets, shares, totalAssets_);
    _withdraw(caller, receiver, owner, assets, shares);

    return shares;
  }

  /// @inheritdoc IERC4626
  function maxRedeem(address owner) public view override returns (uint256) {
    return _maxWithdraw(owner, totalAssets(), true);
  }

  /**
   * @notice Slippage protected `redeem()` per EIP5143.
   *
   * @param shares amount that will be redeemed
   * @param receiver to whom asset equivalent of `shares` amount will be transferred
   * @param owner of the shares
   * @param minAssets amount that `receiver` must expect
   *
   * @dev Refer to https://eips.ethereum.org/EIPS/eip-5143.
   * Requirements:
   * - Must  receive at least `minAssets` when calling `redeem()`.
   */
  function redeem(
    uint256 shares,
    address receiver,
    address owner,
    uint256 minAssets
  )
    public
    virtual
    returns (uint256)
  {
    uint256 receivedAssets = redeem(shares, receiver, owner);
    if (receivedAssets < minAssets) {
      revert VaultAssets__redeem_slippageTooHigh();
    }
    return receivedAssets;
  }

  /// @inheritdoc IERC4626
  function redeem(
    uint256 shares,
    address receiver,
    address owner
  )
    public
    override
    returns (uint256)
  {
    address caller = msg.sender;
    uint256 totalAssets_ = totalAssets();
    // Gas saving `PreviewRedeem` without having to call again `totalAssets()`.
    uint256 assets = _previewRedeem(shares, totalAssets_);

    _withdrawChecks(caller, receiver, owner, assets, shares, totalAssets_);
    _withdraw(caller, receiver, owner, assets, shares);

    return assets;
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

  /**
   * @dev Runs common checks for all "deposit" or "mint" actions in this vault.
   * Requirements:
   * - Must revert for all conditions not passed.
   *
   * @param receiver of the deposit
   * @param assets being deposited
   * @param shares being minted for `receiver`
   */
  function _depositChecks(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  )
    private
    view
  {
    _checkAddressNotZero(caller);
    _checkAddressNotZero(receiver);
    _checkAmountIsNotZero(assets);
    _checkAmountIsNotZero(shares);

    if (assets < s.properties.minAmount) {
      revert VaultAssets__deposit_lessThanMin();
    }
  }

  /**
   * @dev Perform `_deposit()` at provider {IERC4626-deposit}.
   * Requirements:
   * - Must call `activeProvider` in `_executeProviderAction()`.
   * - Must emit a Deposit event.
   *
   * @param caller or {msg.sender}
   * @param receiver to whom `assets` are credited by `shares` amount
   * @param assets amount transferred during this deposit
   * @param shares amount credited to `receiver` during this deposit
   */
  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  )
    internal
    whenNotPaused(VaultActions.Deposit)
  {
    SafeERC20.safeTransferFrom(s.properties.asset, caller, address(this), assets);
    LibVaultLogic._executeProviderAction(assets, "deposit", s.extAddresses.activeProvider);
    _mint(receiver, shares);

    emit Deposit(caller, receiver, assets, shares);
  }

  /**
   * @dev Runs common checks for all "withdraw" or "redeem" actions in this vault.
   * Requirements:
   * - Must revert for all conditions not passed.
   *
   * @param caller in msg.sender context
   * @param receiver of the withdrawn assets
   * @param owner of the withdrawn assets
   * @param assets being withdrawn
   * @param shares being burned for `owner`
   */
  function _withdrawChecks(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares,
    uint256 totalAssets_
  )
    private
  {
    _checkAddressNotZero(caller);
    _checkAddressNotZero(receiver);
    _checkAddressNotZero(owner);
    _checkAmountIsNotZero(assets);
    _checkAmountIsNotZero(shares);

    if (assets > _maxWithdraw(owner, totalAssets_, false)) {
      revert VaultAssets__withdraw_moreThanMax();
    }
    if (caller != owner) {
      _spendWithdrawAllowance(owner, caller, receiver, shares);
    }
  }

  /**
   * @dev Perform `_withdraw()` at provider {IERC4626-withdraw}.
   * Requirements:
   * - Must call `activeProvider` in `_executeProviderAction()`.
   * - Must emit a Withdraw event.
   *
   * @param caller or {msg.sender}
   * @param receiver to whom `assets` amount will be transferred to
   * @param owner to whom `shares` will be burned
   * @param assets amount transferred during this withraw
   * @param shares amount burned to `owner` during this withdraw
   */
  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  )
    internal
    whenNotPaused(VaultActions.Withdraw)
  {
    _burn(owner, shares);
    LibVaultLogic._executeProviderAction(assets, "withdraw", s.extAddresses.activeProvider);
    SafeERC20.safeTransfer(s.properties.asset, receiver, assets);

    emit Withdraw(caller, receiver, owner, assets, shares);
  }

  /// @dev Private version of {IERC4626-maxWithdraw()} does not call `totalAssets()` at any point.
  function _maxWithdraw(
    address owner,
    uint256 totalAssets_,
    bool maxRedeem_
  )
    private
    view
    returns (uint256)
  {
    if (paused(VaultActions.Withdraw)) {
      return 0;
    } else if (address(s.properties.debtAsset) == address(0)) {
      // Handle case where this vault handles no debt.
      if (!maxRedeem_) {
        return LibVaultLogic._convertToAssets(
          s.accounting.assetShareBalances[owner],
          totalAssets_,
          s.accounting.totalAssetShareSupply,
          Rounding.Down
        );
      } else {
        return s.accounting.assetShareBalances[owner];
      }
    } else {
      // Handle case where this vault handles debt.
      uint256 freeAssets = LibVaultLogic._computeFreeAssets(
        LibVaultLogic._convertToAssets(
          s.accounting.assetShareBalances[owner],
          totalAssets_,
          s.accounting.totalAssetShareSupply,
          Rounding.Down
        ),
        IVault(address(this)).convertToDebt(s.accounting.debtShareBalances[owner]),
        s.properties.debtDecimals,
        s.extAddresses.oracle.getPriceOf(
          address(s.properties.asset), address(s.properties.debtAsset), s.properties.assetDecimals
        ),
        s.properties.maxLtv
      );

      if (!maxRedeem_) {
        return freeAssets;
      } else {
        return LibVaultLogic._convertToShares(
          freeAssets, totalAssets_, s.accounting.totalAssetShareSupply, Rounding.Down
        );
      }
    }
  }

  /// @dev Private version of {IERC4626-previewDeposit} does not call `totalAssets()`
  function _previewDeposit(uint256 assets, uint256 totalAssets_) private view returns (uint256) {
    return LibVaultLogic._convertToShares(
      assets, totalAssets_, s.accounting.totalAssetShareSupply, Rounding.Down
    );
  }

  /// @dev Private version of {IERC4626-previewMint} does not call `totalAssets()`
  function _previewMint(uint256 shares, uint256 totalAssets_) private view returns (uint256) {
    return LibVaultLogic._convertToAssets(
      shares, totalAssets_, s.accounting.totalAssetShareSupply, Rounding.Up
    );
  }

  /// @dev Private version of {IERC4626-previewWithdraw} does not call `totalAssets()`
  function _previewWithdraw(uint256 assets, uint256 totalAssets_) private view returns (uint256) {
    return LibVaultLogic._convertToShares(
      assets, totalAssets_, s.accounting.totalAssetShareSupply, Rounding.Up
    );
  }

  /// @dev Private version of {IERC4626-previewRedeem} does not call `totalAssets()`
  function _previewRedeem(uint256 shares, uint256 totalAssets_) private view returns (uint256) {
    return LibVaultLogic._convertToAssets(
      shares, totalAssets_, s.accounting.totalAssetShareSupply, Rounding.Down
    );
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
    _checkAmountIsNotZero(amount);

    _beforeTokenTransfer(from, to, amount);

    uint256 fromBalance = s.accounting.assetShareBalances[from];
    // uint256 fromBalance = _balances[from];
    if (amount > fromBalance) {
      revert VaultAssets__tranfer_amountExceedsBalance();
    }
    unchecked {
      s.accounting.assetShareBalances[from] = fromBalance - amount;
      // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
      // decrementing then incrementing.
      s.accounting.assetShareBalances[to] += amount;
    }

    emit Transfer(from, to, amount);

    _afterTokenTransfer(from, to, amount);
  }

  /**
   * @dev Creates `amount` tokens and assigns them to `account`, increasing
   * the total supply.
   *
   * Emits a {Transfer} event with `from` set to the zero address.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   */
  function _mint(address account, uint256 amount) internal virtual {
    _checkAddressNotZero(account);

    _beforeTokenTransfer(address(0), account, amount);

    s.accounting.totalAssetShareSupply += amount;
    unchecked {
      // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
      s.accounting.assetShareBalances[account] += amount;
    }
    emit Transfer(address(0), account, amount);

    _afterTokenTransfer(address(0), account, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`, reducing the
   * total supply.
   *
   * Emits a {Transfer} event with `to` set to the zero address.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   * - `account` must have at least `amount` tokens.
   */
  function _burn(address account, uint256 amount) internal virtual {
    _checkAddressNotZero(account);

    _beforeTokenTransfer(account, address(0), amount);

    uint256 accountBalance = s.accounting.assetShareBalances[account];
    if (amount > accountBalance) {
      revert ERC20__burn_amountExceedsBalance();
    }
    unchecked {
      s.accounting.assetShareBalances[account] = accountBalance - amount;
      // Overflow not possible: amount <= accountBalance <= totalSupply.
      s.accounting.totalAssetShareSupply -= amount;
    }

    emit Transfer(account, address(0), amount);

    _afterTokenTransfer(account, address(0), amount);
  }

  /**
   * @dev Sets assets `amount` as the allowance of `operator` over the `owner`'s assets.
   * This internal function is equivalent to `approve`.
   * Requirements:
   * - Must only be used in `asset` withdrawal logic.
   * - Must check `owner` cannot be the zero address.
   * - Much check `operator` cannot be the zero address.
   * - Must emits an {WithdrawApproval} event.
   *
   * @param owner address who is providing `withdrawAllowance`
   * @param operator address who is allowed to operate the allowance
   * @param receiver address who can spend the allowance
   * @param amount of allowance
   *
   */
  function _setWithdrawAllowance(
    address owner,
    address operator,
    address receiver,
    uint256 amount
  )
    internal
  {
    _checkAddressNotZero(owner);
    _checkAddressNotZero(operator);
    _checkAddressNotZero(receiver);

    s.accounting.withdrawAllowance[owner][operator][receiver] = amount;

    emit WithdrawApproval(owner, operator, receiver, amount);
  }

  /**
   * @dev Spends `withdrawAllowance`.
   * Based on OZ {ERC20-spendAllowance} for `asset` shares.
   *
   * @param owner address who is spending `withdrawAllowance`
   * @param operator address who is allowed to operate the allowance
   * @param receiver address who can spend the allowance
   * @param amount of allowance
   */
  function _spendWithdrawAllowance(
    address owner,
    address operator,
    address receiver,
    uint256 amount
  )
    internal
  {
    uint256 currentAllowance = s.accounting.withdrawAllowance[owner][operator][receiver];
    if (currentAllowance != type(uint256).max) {
      if (amount > currentAllowance) {
        revert VaultAssets__insufficientWithdrawAllowance();
      }
      unchecked {
        _setWithdrawAllowance(owner, operator, receiver, currentAllowance - amount);
      }
    }
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
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal view {
    if (address(s.properties.debtAsset) != address(0)) {
      // Handle case when this vault is IERC4627
      if (from != address(0) && to != address(0)) {
        /**
         * @dev Hook check activated only when called by OZ {ERC20-_transfer}
         * User must not be able to transfer asset-shares locked as collateral
         */
        if (amount > maxRedeem(from)) {
          revert VaultAssets__beforeTokenTransfer_moreThanMax();
        }
      }
    }
  }

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
      revert VaultAssets__checkAddresNotZero_invalidInput();
    }
  }

  function _checkAmountIsNotZero(uint256 amount) internal pure {
    if (amount == 0) {
      revert VaultAssets__checkAmountIsNotZero_invalidInput();
    }
  }
}
