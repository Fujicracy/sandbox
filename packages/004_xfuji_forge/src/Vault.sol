// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import "./interfaces/ILendingProvider.sol";
import "./interfaces/IFujiOracle.sol";

contract Vault is ERC4626 {
  using Math for uint256;

  struct Factor {
    uint64 num;
    uint64 denum;
  }

  event Borrow(address indexed caller, address indexed owner, uint256 debt, uint256 shares);

  event Payback(address indexed caller, address indexed owner, uint256 debt, uint256 shares);

  IERC20Metadata internal immutable _debtAsset;

  uint256 public debtSharesSupply;

  mapping(address => uint256) internal _debtShares;

  ILendingProvider[] internal _providers;
  ILendingProvider public activeProvider;

  IFujiOracle public oracle;

  Factor public maxLtv;

  Factor public liqRatio;

  constructor(
    address asset,
    address debtAsset_,
    address fujiOracle,
    Factor memory maxLtv_,
    Factor memory liqRatio_
  ) ERC4626(IERC20Metadata(asset)) ERC20("Flenda Vault Shares", "fVshs") {
    _debtAsset = IERC20Metadata(debtAsset_);
    oracle = IFujiOracle(fujiOracle);
    maxLtv = maxLtv_;
    liqRatio = liqRatio_;
  }

  ///////////////////////////////////////////////
  /// Asset management overrides from ERC4626 ///
  ///////////////////////////////////////////////

  /** @dev Overriden to perform _deposit adding flow at lending provider {IERC4262-deposit}. */
  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  ) internal override {
    // If _asset is ERC777, `transferFrom` can trigger a reenterancy BEFORE the transfer happens through the
    // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
    // calls the vault, which is assumed not malicious.
    //
    // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
    // assets are transfered and before the shares are minted, which is a valid state.
    // slither-disable-next-line reentrancy-no-eth
    address asset = asset();
    SafeERC20.safeTransferFrom(IERC20(asset), caller, address(this), assets);
    address spender = activeProvider.approveOperator(asset);
    SafeERC20.safeApprove(IERC20(asset), spender, assets);
    activeProvider.deposit(asset, assets);
    _mint(receiver, shares);

    emit Deposit(caller, receiver, assets, shares);
  }

  /** @dev Overriden to perform withdraw checks {IERC4262-withdraw}. */
  function withdraw(
    uint256 assets,
    address receiver,
    address onBehalf
  ) public override returns (uint256) {
    // TODO Need to add security to onBehalf !!!!!!!!
    require(assets > 0, "Wrong input");
    require(assets <= maxWithdraw(onBehalf), "Withdraw more than max");

    uint256 shares = previewWithdraw(assets);
    _withdraw(_msgSender(), receiver, onBehalf, assets, shares);

    return shares;
  }

  /** @dev Overriden to check assets locked by debt {IERC4262-maxWithdraw}. */
  function maxWithdraw(address owner) public view override returns (uint256) {
    return _computeFreeAssets(owner);
  }

  /** @dev Overriden to check shares locked by debt {IERC4262-maxRedeem}. */
  function maxRedeem(address owner) public view override returns (uint256) {
    return _convertToShares(_computeFreeAssets(owner), Math.Rounding.Down);
  }

  /** @dev Overriden to perform _withdraw adding flow at lending provider {IERC4262-withdraw}. */
  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal override {
    // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
    // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
    // calls the vault, which is assumed not malicious.
    //
    // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
    // shares are burned and after the assets are transfered, which is a valid state.
    _burn(owner, shares);
    address asset = asset();
    activeProvider.withdraw(asset, assets);
    SafeERC20.safeTransfer(IERC20(asset), receiver, assets);

    emit Withdraw(caller, receiver, owner, assets, shares);
  }

  /** @dev Overriden See {IERC4262-redeem}. */
  function redeem(
    uint256 shares,
    address receiver,
    address onBehalf
  ) public override returns (uint256) {
    require(shares <= maxRedeem(onBehalf), "Redeem more than max");

    uint256 assets = previewRedeem(shares);
    _withdraw(_msgSender(), receiver, onBehalf, assets, shares);

    return assets;
  }

  ///////////////////////////////////////////////////////////
  /// Debt shares management; functions based on ERC4626. ///
  ///////////////////////////////////////////////////////////

  /** @dev Inspired on {IERC20Metadata-decimals}. */
  function debtDecimals() public view returns (uint8) {
    return decimals();
  }

  /** @dev Based on {IERC4262-asset}. */
  function debtAsset() public view returns (address) {
    return address(_debtAsset);
  }

  /** @dev Based on {IERC4262-totalAssets}. */
  function totalDebt() public view returns (uint256) {
    return _computeTotalDebt();
  }

  /** @dev Based on {IERC4262-convertToShares}. */
  function convertDebtToShares(uint256 debt) public view returns (uint256 shares) {
    return _convertDebtToShares(debt, Math.Rounding.Down);
  }

  /** @dev Based on {IERC4262-convertToAssets}. */
  function convertToDebt(uint256 shares) public view returns (uint256 debt) {
    return _convertToDebt(shares, Math.Rounding.Down);
  }

  /** @dev Based on {IERC4262-maxDeposit}. */
  function maxBorrow(address borrower) public view returns (uint256) {
    return _computeMaxBorrow(borrower);
  }

  /** @dev Based on {IERC4262-deposit}. */
  function borrow(uint256 debt, address onBehalf) public returns (uint256) {
    // TODO Need to add security to onBehalf !!!!!!!!
    require(debt > 0, "Wrong input");
    require(debt <= maxBorrow(onBehalf), "Not enough assets");

    uint256 shares = convertDebtToShares(debt);
    _borrow(_msgSender(), onBehalf, debt, shares);

    return shares;
  }

  /**
   * @dev Burns debtShares from onBehalf.
   * - MUST emit the Payback event.
   */
  function payback(uint256 debt, address onBehalf) public virtual returns (uint256) {
    require(debt > 0, "Wrong input");
    require(debt <= convertToDebt(_debtShares[onBehalf]), "Payback more than max");

    uint256 shares = convertDebtToShares(debt);
    _payback(_msgSender(), onBehalf, debt, shares);

    return shares;
  }

  function _computeTotalDebt() internal view returns (uint256 debt) {
    for (uint256 i = 0; i < _providers.length; ) {
      debt += _providers[i].getBorrowBalance(debtAsset(), address(this));
      unchecked {
        ++i;
      }
    }
  }

  function _computeMaxBorrow(address borrower) internal view returns (uint256 max) {
    uint256 price = oracle.getPriceOf(debtAsset(), asset(), _debtAsset.decimals());
    uint256 assetShares = balanceOf(borrower);
    uint256 assets = convertToAssets(assetShares);
    uint256 debtShares = _debtShares[borrower];
    uint256 debt = convertToDebt(debtShares);

    uint256 baseUserMaxBorrow = ((assets * maxLtv.num * price) /
      (maxLtv.denum * 10**IERC20Metadata(asset()).decimals()));
    max = baseUserMaxBorrow > debt ? baseUserMaxBorrow - debt : 0;
  }

  function _computeFreeAssets(address owner) internal view returns (uint256 freeAssets) {
    uint256 debtShares = _debtShares[owner];
    bool hasDebtShares = _debtShares[owner] > 0 ? true : false;
    if (hasDebtShares) {
      return _convertToAssets(balanceOf(owner), Math.Rounding.Down);
    } else {
      uint256 debt = convertToDebt(debtShares);
      uint256 price = oracle.getPriceOf(asset(), debtAsset(), IERC20Metadata(asset()).decimals());
      uint256 lockedAssets = (debt * maxLtv.denum * price) /
        (maxLtv.num * 10**_debtAsset.decimals());
      uint256 assetShares = balanceOf(owner);
      uint256 assets = convertToAssets(assetShares);

      freeAssets = assets > lockedAssets ? assets - lockedAssets : 0;
    }
  }

  /**
   * @dev Internal conversion function (from debt to shares) with support for rounding direction.
   * Will revert if debt > 0, debtSharesSupply > 0 and totalDebt = 0. That corresponds to a case where debt
   * would represent an infinite amout of shares.
   */
  function _convertDebtToShares(uint256 debt, Math.Rounding rounding)
    internal
    view
    virtual
    returns (uint256 shares)
  {
    uint256 supply = debtSharesSupply;
    return
      (debt == 0 || supply == 0)
        ? debt.mulDiv(10**decimals(), 10**_debtAsset.decimals(), rounding)
        : debt.mulDiv(supply, totalDebt(), rounding);
  }

  /**
   * @dev Internal conversion function (from shares to debt) with support for rounding direction.
   */
  function _convertToDebt(uint256 shares, Math.Rounding rounding)
    internal
    view
    virtual
    returns (uint256 assets)
  {
    uint256 supply = debtSharesSupply;
    return
      (supply == 0)
        ? shares.mulDiv(10**_debtAsset.decimals(), 10**decimals(), rounding)
        : shares.mulDiv(totalDebt(), supply, rounding);
  }

  /**
   * @dev Borrow/mintDebtShares common workflow.
   */
  function _borrow(
    address caller,
    address onBehalf,
    uint256 debt,
    uint256 shares
  ) internal {
    _mintDebtShares(onBehalf, shares);
    activeProvider.borrow(debtAsset(), debt);

    // If _asset is ERC777, `transferFrom` can trigger a reenterancy BEFORE the transfer happens through the
    // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
    // calls the vault, which is assumed not malicious.
    //
    // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
    // assets are transfered and before the shares are minted, which is a valid state.
    // slither-disable-next-line reentrancy-no-eth
    SafeERC20.safeTransferFrom(_debtAsset, caller, address(this), debt);

    emit Borrow(caller, onBehalf, debt, shares);
  }

  /**
   * @dev Payback/burnDebtShares common workflow.
   */
  function _payback(
    address caller,
    address onBehalf,
    uint256 debt,
    uint256 shares
  ) internal {
    // If _asset is ERC777, `transferFrom` can trigger a reenterancy BEFORE the transfer happens through the
    // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
    // calls the vault, which is assumed not malicious.
    //
    // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
    // assets are transfered and before the shares are minted, which is a valid state.
    // slither-disable-next-line reentrancy-no-eth
    SafeERC20.safeTransferFrom(_debtAsset, caller, address(this), debt);
    address spender = activeProvider.approveOperator(debtAsset());
    SafeERC20.safeApprove(_debtAsset, spender, debt);

    activeProvider.payback(debtAsset(), debt);
    _burnDebtShares(onBehalf, shares);

    emit Payback(caller, onBehalf, debt, shares);
  }

  function _mintDebtShares(address account, uint256 amount) internal {
    require(account != address(0), "Mint to the zero address");
    debtSharesSupply += amount;
    _debtShares[account] += amount;
  }

  function _burnDebtShares(address account, uint256 amount) internal {
    require(account != address(0), "Mint to the zero address");
    uint256 accountBalance = _debtShares[account];
    require(accountBalance >= amount, "Burn amount exceeds balance");
    unchecked {
      _debtShares[account] = accountBalance - amount;
    }
    debtSharesSupply -= amount;
  }

  /// Public getters.

  function getProviders() external view returns (ILendingProvider[] memory list) {
    list = _providers;
  }

  /// Token transfer hooks.

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal view override {
    to;
    require(amount <= maxRedeem(from), "Transfer more than max");
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal pure override {
    from;
    to;
    amount;
  }

  ///////////////////////////
  /// Admin set functions ///
  ///////////////////////////

  function setOracle(IFujiOracle newOracle) external {
    // TODO needs admin restriction
    // TODO needs input validation
    oracle = newOracle;
    // TODO needs to emit event.
  }

  function setProviders(ILendingProvider[] memory providers) external {
    // TODO needs admin restriction
    // TODO needs input validation
    _providers = providers;
    // TODO needs to emit event.
  }

  function setActiveProvider(ILendingProvider activeProvider_) external {
    // TODO needs admin restriction
    // TODO needs input validation
    activeProvider = activeProvider_;
    // TODO needs to emit event.
  }

  function setMaxLtv(Factor calldata maxLtv_) external {
    // TODO needs admin restriction
    // TODO needs input validation
    maxLtv = maxLtv_;
    // TODO needs to emit event.
  }

  function setLiqRatio(Factor calldata liqRatio_) external {
    // TODO needs admin restriction
    // TODO needs input validation
    liqRatio = liqRatio_;
    // TODO needs to emit event.
  }
}
