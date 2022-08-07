// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "../../interfaces/ILendingProvider.sol";
import "../../interfaces/IFujiOracle.sol";

contract BorrowingVault is ERC4626 {
  using Math for uint256;
  using Address for address;

  struct Factor {
    uint64 num;
    uint64 denum;
  }

  event Borrow(address indexed caller, address indexed owner, uint256 debt, uint256 shares);

  event Payback(address indexed caller, address indexed owner, uint256 debt, uint256 shares);

  address public immutable chief;

  IERC20Metadata internal immutable _debtAsset;

  uint256 public debtSharesSupply;

  mapping(address => uint256) internal _debtShares;

  ILendingProvider[] internal _providers;
  ILendingProvider public activeProvider;

  IFujiOracle public oracle;

  Factor public maxLtv = Factor(75, 100);

  Factor public liqRatio = Factor(5, 100);

  constructor(
    address asset_,
    address debtAsset_,
    address oracle_,
    address chief_
  )
    ERC4626(IERC20Metadata(asset_))
    ERC20(
      // ex: Fuji-X Dai Stablecoin Vault Shares
      string(abi.encodePacked("Fuji-X ", IERC20Metadata(asset_).name(), " Vault Shares")),
      // ex: fxDAI
      string(abi.encodePacked("fx", IERC20Metadata(asset_).symbol()))
    )
  {
    _debtAsset = IERC20Metadata(debtAsset_);
    oracle = IFujiOracle(oracle_);
    chief = chief_;
  }

  ///////////////////////////////////////////////
  /// Asset management overrides from ERC4626 ///
  ///////////////////////////////////////////////

  /** @dev Overriden to check assets locked in activeProvider {IERC4626-totalAssets}. */
  function totalAssets() public view virtual override returns (uint256) {
    return activeProvider.getDepositBalance(asset(), address(this));
  }

  /** @dev Overriden to check assets locked by debt {IERC4626-maxWithdraw}. */
  function maxWithdraw(address owner) public view override returns (uint256) {
    return _computeFreeAssets(owner);
  }

  /** @dev Overriden to check shares locked by debt {IERC4626-maxRedeem}. */
  function maxRedeem(address owner) public view override returns (uint256) {
    return _convertToShares(_computeFreeAssets(owner), Math.Rounding.Down);
  }

  /** @dev Overriden to perform withdraw checks {IERC4626-withdraw}. */
  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public override returns (uint256) {
    // TODO Need to add security to owner !!!!!!!!
    require(assets > 0, "Wrong input");
    require(assets <= maxWithdraw(owner), "Withdraw more than max");

    uint256 shares = previewWithdraw(assets);
    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return shares;
  }

  /** @dev Overriden See {IERC4626-redeem}. */
  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) public override returns (uint256) {
    require(shares <= maxRedeem(owner), "Redeem more than max");

    uint256 assets = previewRedeem(shares);
    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return assets;
  }

  /// Token transfer hooks.
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal view override {
    to;
    if (from != address(0)) require(amount <= maxRedeem(from), "Transfer more than max");
  }

  /** @dev Overriden to perform _deposit adding flow at lending provider {IERC4626-deposit}. */
  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  ) internal override {
    address asset = asset();

    SafeERC20.safeTransferFrom(IERC20(asset), caller, address(this), assets);
    _executeProviderAction(asset, assets, "deposit");
    _mint(receiver, shares);

    emit Deposit(caller, receiver, assets, shares);
  }

  /** @dev Overriden to perform _withdraw adding flow at lending provider {IERC4626-withdraw}. */
  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal override {
    address asset = asset();

    _burn(owner, shares);
    _executeProviderAction(asset, assets, "withdraw");
    SafeERC20.safeTransfer(IERC20(asset), receiver, assets);

    emit Withdraw(caller, receiver, owner, assets, shares);
  }

  ///////////////////////////////////////////////////////////
  /// Debt shares management; functions based on ERC4626. ///
  ///////////////////////////////////////////////////////////

  /** @dev Inspired on {IERC20Metadata-decimals}. */
  function debtDecimals() public view returns (uint8) {
    return _debtAsset.decimals();
  }

  /** @dev Based on {IERC4626-asset}. */
  function debtAsset() public view returns (address) {
    return address(_debtAsset);
  }

  /** @dev Based on {IERC4626-totalAssets}. */
  function totalDebt() public view returns (uint256) {
    return activeProvider.getBorrowBalance(debtAsset(), address(this));
  }

  /** @dev Based on {IERC4626-convertToShares}. */
  function convertDebtToShares(uint256 debt) public view returns (uint256 shares) {
    return _convertDebtToShares(debt, Math.Rounding.Down);
  }

  /** @dev Based on {IERC4626-convertToAssets}. */
  function convertToDebt(uint256 shares) public view returns (uint256 debt) {
    return _convertToDebt(shares, Math.Rounding.Down);
  }

  /** @dev Based on {IERC4626-maxDeposit}. */
  function maxBorrow(address borrower) public view returns (uint256) {
    return _computeMaxBorrow(borrower);
  }

  /** @dev Based on {IERC4626-deposit}. */
  function borrow(
    uint256 debt,
    address receiver,
    address owner
  ) public returns (uint256) {
    // TODO Need to add security to owner !!!!!!!!
    require(debt > 0, "Wrong input");
    require(debt <= maxBorrow(owner), "Not enough assets");

    uint256 shares = convertDebtToShares(debt);
    _borrow(_msgSender(), receiver, owner, debt, shares);

    return shares;
  }

  /**
   * @dev Burns debtShares from owner.
   * - MUST emit the Payback event.
   */
  function payback(uint256 debt, address owner) public virtual returns (uint256) {
    require(debt > 0, "Wrong input");
    require(debt <= convertToDebt(_debtShares[owner]), "Payback more than max");

    uint256 shares = convertDebtToShares(debt);
    _payback(_msgSender(), owner, debt, shares);

    return shares;
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

    // no debt
    if (debtShares == 0) {
      freeAssets = convertToAssets(balanceOf(owner));
    } else {
      uint256 debt = convertToDebt(debtShares);
      uint256 price = oracle.getPriceOf(asset(), debtAsset(), IERC20Metadata(asset()).decimals());
      uint256 lockedAssets = (debt * maxLtv.denum * price) /
        (maxLtv.num * 10**_debtAsset.decimals());
      uint256 assets = convertToAssets(balanceOf(owner));

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
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal {
    _mintDebtShares(owner, shares);

    address asset = debtAsset();
    _executeProviderAction(asset, assets, "borrow");

    SafeERC20.safeTransfer(IERC20(asset), receiver, assets);

    emit Borrow(caller, owner, assets, shares);
  }

  /**
   * @dev Payback/burnDebtShares common workflow.
   */
  function _payback(
    address caller,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal {
    address asset = debtAsset();
    SafeERC20.safeTransferFrom(IERC20(asset), caller, address(this), assets);

    _executeProviderAction(asset, assets, "payback");

    _burnDebtShares(owner, shares);

    emit Payback(caller, owner, assets, shares);
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

  function _executeProviderAction(
    address asset,
    uint256 assets,
    string memory name
  ) internal {
    bytes memory data = abi.encodeWithSignature(
      string(abi.encodePacked(name, "(address,uint256)")),
      asset,
      assets
    );
    address(activeProvider).functionDelegateCall(
      data,
      string(abi.encodePacked(name, ": delegate call failed"))
    );
  }

  /// Public getters.

  function getProviders() external view returns (ILendingProvider[] memory list) {
    list = _providers;
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
    address asset = asset();
    SafeERC20.safeApprove(IERC20(asset), activeProvider.approvedOperator(asset), type(uint256).max);
    address debt = debtAsset();
    SafeERC20.safeApprove(IERC20(debt), activeProvider.approvedOperator(debt), type(uint256).max);
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
