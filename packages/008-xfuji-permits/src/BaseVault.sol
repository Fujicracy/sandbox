// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

/**
 * @title Vault Interface.
 * @author Fujidao Labs
 * @notice Defines the interface for vault operations extending from IERC4626.
 */
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IVault} from "@xfuji/interfaces/IVault.sol";
import {ILendingProvider} from "@xfuji/interfaces/ILendingProvider.sol";
import {IFujiOracle} from "@xfuji/interfaces/IFujiOracle.sol";
import {VaultPermissions} from "./VaultPermissions.sol";

import "forge-std/console.sol";

abstract contract BaseVault is ERC20, VaultPermissions, IVault {
    using Math for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    IERC20Metadata internal immutable _asset;
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
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) VaultPermissions(name_, "1") {
        _asset = IERC20Metadata(asset_);
        _debtAsset = IERC20Metadata(debtAsset_);
        oracle = IFujiOracle(oracle_);
    }

    ////////////////////////////////////////////////////
    /// Asset management: allowance-overrides IERC20 ///
    /// Overrides required to handle all in assets   ///
    ////////////////////////////////////////////////////

    /**
     * @dev Override to call {VaultPermissions-assetAllowance}.
     * Returns the share amount of VaultPermissions-assetAllowance.
     */
    function allowance(address owner, address spender)
        public
        view
        override(ERC20, IERC20)
        returns (uint256)
    {
        return convertToShares(assetAllowance(owner, spender));
    }

    /**
     * @dev Override to call {VaultPermissions-_setAssetAllowance}.
     * Converts approve shares argument to assets in VaultPermissions-_assetAllowance.
     * Recommend to use increase/decrease methods see OZ notes for {IERC20-approve}.
     */
    function approve(address spender, uint256 shares)
        public
        override(ERC20, IERC20)
        returns (bool)
    {
        address owner = _msgSender();
        _setAssetAllowance(owner, spender, convertToAssets(shares));
        return true;
    }

    /**
     * @dev Override to call {VaultPermissions-increaseAssetAllowance}.
     * Converts extraShares argument to assets in VaultPermissions-increaseAssetAllowance.
     */
    function increaseAllowance(address spender, uint256 extraShares)
        public
        override
        returns (bool)
    {
        increaseAssetAllowance(spender, convertToAssets(extraShares));
        return true;
    }

    /**
     * @dev Override to call {VaultPermissions-decreaseAssetAllowance}.
     * Converts subtractedShares argument to assets in VaultPermissions-decreaseAssetAllowance.
     */
    function decreaseAllowance(address spender, uint256 subtractedShares)
        public
        override
        returns (bool)
    {
        decreaseAssetAllowance(spender, convertToAssets(subtractedShares));
        return true;
    }

    /**
     * @dev Override to call {VaultPermissions-_spendAssetAllowance}.
     * Converts shares argument to assets in VaultPermissions-_spendAssetAllowance.
     * This internal function is called during ERC4626-transferFrom.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 shares
    ) internal override {
        _spendAssetAllowance(owner, spender, convertToAssets(shares));
    }

    ////////////////////////////////////////////
    /// Asset management: overrides IERC4626 ///
    ////////////////////////////////////////////

    /**
     * @dev See {IERC4626-asset}.
     */
    function asset() public view virtual override returns (address) {
        return address(_asset);
    }

    /**
     * @dev Overriden to check assets locked in activeProvider {IERC4626-totalAssets}.
     */
    function totalAssets() public view virtual override returns (uint256) {
        return activeProvider.getDepositBalance(asset(), address(this));
    }

    /**
     * @dev See {IERC4626-convertToShares}.
     */
    function convertToShares(uint256 assets)
        public
        view
        virtual
        override
        returns (uint256 shares)
    {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    /**
     * @dev See {IERC4626-convertToAssets}.
     */
    function convertToAssets(uint256 shares)
        public
        view
        virtual
        override
        returns (uint256 assets)
    {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    /**
     * @dev See {IERC4626-maxDeposit}.
     */
    function maxDeposit(address)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _isVaultCollateralized() ? type(uint256).max : 0;
    }

    /**
     * @dev See {IERC4626-maxMint}.
     */
    function maxMint(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @dev Overriden to check assets locked by debt {IERC4626-maxWithdraw}.
     */
    function maxWithdraw(address owner) public view override returns (uint256) {
        return _computeFreeAssets(owner);
    }

    /**
     * @dev Overriden to check shares locked by debt {IERC4626-maxRedeem}.
     */
    function maxRedeem(address owner) public view override returns (uint256) {
        return _convertToShares(_computeFreeAssets(owner), Math.Rounding.Down);
    }

    /**
     * @dev See {IERC4626-previewDeposit}.
     */
    function previewDeposit(uint256 assets)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    /**
     * @dev See {IERC4626-previewMint}.
     */
    function previewMint(uint256 shares)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _convertToAssets(shares, Math.Rounding.Up);
    }

    /**
     * @dev See {IERC4626-previewWithdraw}.
     */
    function previewWithdraw(uint256 assets)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _convertToShares(assets, Math.Rounding.Up);
    }

    /**
     * @dev See {IERC4626-previewRedeem}.
     */
    function previewRedeem(uint256 shares)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    /**
     * @dev See {IERC4626-deposit}.
     */
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        returns (uint256)
    {
        require(
            assets <= maxDeposit(receiver),
            "ERC4626: deposit more than max"
        );

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    /**
     * @dev See {IERC4626-mint}.
     */
    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        returns (uint256)
    {
        require(shares <= maxMint(receiver), "ERC4626: mint more than max");

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    /**
     * @dev Overriden to perform withdraw additional checks from {IERC4626-withdraw}.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256) {
        require(assets > 0, "Wrong input");
        console.log('maxWithdraw',maxWithdraw(owner));
        require(assets <= maxWithdraw(owner), "Withdraw more than max");

        address caller = _msgSender();
        if (caller != owner) {
            _spendAssetAllowance(owner, caller, assets);
        }

        uint256 shares = previewWithdraw(assets);
        _withdraw(caller, receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @dev Overriden See {IERC4626-redeem}.
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256) {
        require(shares > 0, "Wrong input");
        require(shares <= maxRedeem(owner), "Redeem more than max");

        address caller = _msgSender();
        uint256 assets = previewRedeem(shares);
        if (caller != owner) {
            _spendAssetAllowance(owner, caller, assets);
        }

        _withdraw(caller, receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     *
     * Will revert if assets > 0, totalSupply > 0 and totalAssets = 0. That corresponds to a case where any asset
     * would represent an infinite amout of shares.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        virtual
        returns (uint256 shares)
    {
        uint256 supply = totalSupply();
        return
            (assets == 0 || supply == 0)
                ? assets.mulDiv(10**decimals(), 10**_asset.decimals(), rounding)
                : assets.mulDiv(supply, totalAssets(), rounding);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        virtual
        returns (uint256 assets)
    {
        uint256 supply = totalSupply();
        return
            (supply == 0)
                ? shares.mulDiv(10**_asset.decimals(), 10**decimals(), rounding)
                : shares.mulDiv(totalAssets(), supply, rounding);
    }

    /**
     * @dev Overriden to perform _deposit adding flow at lending provider {IERC4626-deposit}.
     */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal {
        SafeERC20.safeTransferFrom(
            IERC20(asset()),
            caller,
            address(this),
            assets
        );
        _executeProviderAction(asset(), assets, "deposit");
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    /**
     * @dev Overriden to perform _withdraw adding flow at lending provider {IERC4626-withdraw}.
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal {
        _burn(owner, shares);
        _executeProviderAction(asset(), assets, "withdraw");
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _isVaultCollateralized() private view returns (bool) {
        return totalAssets() > 0 || totalSupply() == 0;
    }

    /// Token transfer hooks

    /**
     * @dev Check if 'from' can move 'shares'.
     * In Lending vault this should let go.
     * In Borrowing vault this should check debt status.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 shares
    ) internal view override {
        to;
        if (from != address(0))
            require(shares <= maxRedeem(from), "Transfer more than max");
    }

    ////////////////////////////////////////////////////
    /// Debt management: based on IERC4626 semantics ///
    ////////////////////////////////////////////////////

    /**
     * @dev Inspired on {IERC20Metadata-decimals}.
     */
    function debtDecimals() public view virtual returns (uint8);

    /**
     * @dev Based on {IERC4626-asset}.
     */
    function debtAsset() public view virtual returns (address);

    /**
     * @dev Based on {IERC4626-totalAssets}.
     */
    function totalDebt() public view virtual returns (uint256);

    /**
     * @dev Based on {IERC4626-convertToShares}.
     */
    function convertDebtToShares(uint256 debt)
        public
        view
        virtual
        returns (uint256 shares);

    /**
     * @dev Based on {IERC4626-convertToAssets}.
     */
    function convertToDebt(uint256 shares)
        public
        view
        virtual
        returns (uint256 debt);

    /**
     * @dev Based on {IERC4626-maxDeposit}.
     */
    function maxBorrow(address borrower) public view virtual returns (uint256);

    /**
     * @dev Based on {IERC4626-deposit}.
     */
    function borrow(
        uint256 debt,
        address receiver,
        address owner
    ) public virtual returns (uint256);

    /**
     * @dev Burns debtShares from owner.
     * - MUST emit the Payback event.
     */
    function payback(uint256 debt, address owner)
        public
        virtual
        returns (uint256);

    /**
     * @dev See {VaultPermissions-debtAllowance}.
     * Implement in {BorrowingVault}
     */
    function debtAllowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        owner;
        spender;
        revert();
    }

    /**
     * @dev See {VaultPermissions-decreaseDebtAllowance}.
     * Implement in {BorrowingVault}
     */
    function increaseDebtAllowance(address spender, uint256 byAmount)
        public
        virtual
        override
        returns (bool)
    {
        spender;
        byAmount;
        revert();
    }

    /**
     * @dev See {VaultPermissions-decreaseDebtAllowance}.
     * Implement in {BorrowingVault}
     */
    function decreaseDebtAllowance(address spender, uint256 byAmount)
        public
        virtual
        override
        returns (bool)
    {
        spender;
        byAmount;
        revert();
    }

    /**
     * @dev See {VaultPermissions-permitDebt}.
     * Implement in {BorrowingVault}
     */
    function permitDebt(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        owner;
        spender;
        value;
        deadline;
        v;
        r;
        s;
        revert();
    }

    function _computeMaxBorrow(address borrower)
        internal
        view
        virtual
        returns (uint256);

    function _computeFreeAssets(address owner)
        internal
        view
        virtual
        returns (uint256);

    /**
     * @dev Internal conversion function (from debt to shares) with support for rounding direction.
     * Will revert if debt > 0, debtSharesSupply > 0 and totalDebt = 0. That corresponds to a case where debt
     * would represent an infinite amout of shares.
     */
    function _convertDebtToShares(uint256 debt, Math.Rounding rounding)
        internal
        view
        virtual
        returns (uint256);

    /**
     * @dev Internal conversion function (from shares to debt) with support for rounding direction.
     */
    function _convertToDebt(uint256 shares, Math.Rounding rounding)
        internal
        view
        virtual
        returns (uint256);

    /**
     * @dev Borrow/mintDebtShares common workflow.
     */
    function _borrow(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual;

    /**
     * @dev Payback/burnDebtShares common workflow.
     */
    function _payback(
        address caller,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual;

    function _mintDebtShares(address account, uint256 amount) internal virtual;

    function _burnDebtShares(address account, uint256 amount) internal virtual;

    ////////////////////////////
    /// Fuji Vault functions ///
    ////////////////////////////

    function _executeProviderAction(
        address assetAddr,
        uint256 assets,
        string memory name
    ) internal {
        bytes memory data = abi.encodeWithSignature(
            string(abi.encodePacked(name, "(address,uint256)")),
            assetAddr,
            assets
        );
        address(activeProvider).functionDelegateCall(
            data,
            string(abi.encodePacked(name, ": delegate call failed"))
        );
    }

    /// Public getters.

    function getProviders()
        external
        view
        returns (ILendingProvider[] memory list)
    {
        list = _providers;
    }

    ///////////////////////////
    /// Admin set functions ///
    ///////////////////////////

    function setOracle(IFujiOracle newOracle) external {
        // TODO needs admin restriction
        // TODO needs input validation
        oracle = newOracle; // TODO needs to emit event.
    }

    function setProviders(ILendingProvider[] memory providers) external {
        // TODO needs admin restriction
        // TODO needs input validation
        _providers = providers; // TODO needs to emit event.
    }

    function setActiveProvider(ILendingProvider activeProvider_) external {
        // TODO needs admin restriction
        // TODO needs input validation
        activeProvider = activeProvider_;
        // TODO needs to emit event.
        SafeERC20.safeApprove(
            IERC20(asset()),
            activeProvider.approvedOperator(asset()),
            type(uint256).max
        );
        if (debtAsset() != address(0))
            SafeERC20.safeApprove(
                IERC20(debtAsset()),
                activeProvider.approvedOperator(debtAsset()),
                type(uint256).max
            );
    }

    function setMaxLtv(Factor calldata maxLtv_) external {
        // TODO needs admin restriction
        // TODO needs input validation
        maxLtv = maxLtv_; // TODO needs to emit event.
    }

    function setLiqRatio(Factor calldata liqRatio_) external {
        // TODO needs admin restriction
        // TODO needs input validation
        liqRatio = liqRatio_; // TODO needs to emit event.
    }
}
