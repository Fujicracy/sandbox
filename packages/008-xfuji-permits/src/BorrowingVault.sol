// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import {BaseVault} from "./BaseVault.sol";
import {VaultPermissions} from "./VaultPermissions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/console.sol";

contract BorrowingVault is BaseVault {
    using Math for uint256;
    using SafeERC20 for IERC20;

    constructor(
        address asset_,
        address debtAsset_,
        address oracle_
    )
        BaseVault(
            // asset_
            asset_,
            // debtAsset_
            debtAsset_,
            //oracle
            oracle_,
            // name_
            string(
                abi.encodePacked(
                    "X-Fuji ",
                    IERC20Metadata(asset_).name(),
                    " Vault Shares"
                )
            ),
            // symbol_
            string(abi.encodePacked("xf", IERC20Metadata(asset_).symbol()))
        )
    {}

    /////////////////////////////////
    /// Debt management overrides ///
    /////////////////////////////////

    /**
     * @dev Inspired on {IERC20Metadata-decimals}.
     */
    function debtDecimals() public view override returns (uint8) {
        return _debtAsset.decimals();
    }

    /**
     * @dev Based on {IERC4626-asset}.
     */
    function debtAsset() public view override returns (address) {
        return address(_debtAsset);
    }

    /**
     * @dev Based on {IERC4626-totalAssets}.
     */
    function totalDebt() public view override returns (uint256) {
        return activeProvider.getBorrowBalance(debtAsset(), address(this));
    }

    /**
     * @dev Based on {IERC4626-convertToShares}.
     */
    function convertDebtToShares(uint256 debt)
        public
        view
        override
        returns (uint256 shares)
    {
        return _convertDebtToShares(debt, Math.Rounding.Down);
    }

    /**
     * @dev Based on {IERC4626-convertToAssets}.
     */
    function convertToDebt(uint256 shares)
        public
        view
        override
        returns (uint256 debt)
    {
        return _convertToDebt(shares, Math.Rounding.Down);
    }

    /**
     * @dev Based on {IERC4626-maxDeposit}.
     */
    function maxBorrow(address borrower)
        public
        view
        override
        returns (uint256)
    {
        return _computeMaxBorrow(borrower);
    }

    /**
     * @dev Based on {IERC4626-deposit}.
     */
    function borrow(
        uint256 debt,
        address receiver,
        address owner
    ) public override returns (uint256) {
        if (msg.sender != owner) {
            _spendDebtAllowance(owner, msg.sender, debt);
        }
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
    function payback(uint256 debt, address owner)
        public
        override
        returns (uint256)
    {
        require(debt > 0, "Wrong input");
        require(
            debt <= convertToDebt(_debtShares[owner]),
            "Payback more than max"
        );

        uint256 shares = convertDebtToShares(debt);
        _payback(_msgSender(), owner, debt, shares);

        return shares;
    }

    /**
     * @dev See {VaultPermissions-debtAllowance}.
     * Implement in {BorrowingVault}
     */
    function debtAllowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return VaultPermissions.debtAllowance(owner, spender);
    }

    /**
     * @dev See {VaultPermissions-decreaseDebtAllowance}.
     * Implement in {BorrowingVault}
     */
    function increaseDebtAllowance(address spender, uint256 byAmount)
        public
        override
        returns (bool)
    {
        return VaultPermissions.increaseDebtAllowance(spender, byAmount);
    }

    /**
     * @dev See {VaultPermissions-decreaseDebtAllowance}.
     * Implement in {BorrowingVault}
     */
    function decreaseDebtAllowance(address spender, uint256 byAmount)
        public
        override
        returns (bool)
    {
        return VaultPermissions.decreaseDebtAllowance(spender, byAmount);
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
        VaultPermissions.permitDebt(owner, spender, value, deadline, v, r, s);
    }

    function _computeMaxBorrow(address borrower)
        internal
        view
        override
        returns (uint256 max)
    {
        uint256 price = oracle.getPriceOf(
            debtAsset(),
            asset(),
            _debtAsset.decimals()
        );
        uint256 assetShares = balanceOf(borrower);
        uint256 assets = convertToAssets(assetShares);
        uint256 debtShares = _debtShares[borrower];
        uint256 debt = convertToDebt(debtShares);

        uint256 baseUserMaxBorrow = ((assets * maxLtv.num * price) /
            (maxLtv.denum * 10**IERC20Metadata(asset()).decimals()));
        max = baseUserMaxBorrow > debt ? baseUserMaxBorrow - debt : 0;
    }

    function _computeFreeAssets(address owner)
        internal
        view
        override
        returns (uint256 freeAssets)
    {
        uint256 debtShares = _debtShares[owner];

        // no debt
        if (debtShares == 0) {
            console.log('debtshareszero');
            freeAssets = convertToAssets(balanceOf(owner));
        } else {
            uint256 debt = convertToDebt(debtShares);
            uint256 price = oracle.getPriceOf(
                asset(),
                debtAsset(),
                IERC20Metadata(asset()).decimals()
            );
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
        override
        returns (uint256 shares)
    {
        uint256 supply = debtSharesSupply;
        return
            (debt == 0 || supply == 0)
                ? debt.mulDiv(
                    10**decimals(),
                    10**_debtAsset.decimals(),
                    rounding
                )
                : debt.mulDiv(supply, totalDebt(), rounding);
    }

    /**
     * @dev Internal conversion function (from shares to debt) with support for rounding direction.
     */
    function _convertToDebt(uint256 shares, Math.Rounding rounding)
        internal
        view
        override
        returns (uint256 assets)
    {
        uint256 supply = debtSharesSupply;
        return
            (supply == 0)
                ? shares.mulDiv(
                    10**_debtAsset.decimals(),
                    10**decimals(),
                    rounding
                )
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
    ) internal override {
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
    ) internal override {
        address asset = debtAsset();
        SafeERC20.safeTransferFrom(
            IERC20(asset),
            caller,
            address(this),
            assets
        );

        _executeProviderAction(asset, assets, "payback");

        _burnDebtShares(owner, shares);

        emit Payback(caller, owner, assets, shares);
    }

    function _mintDebtShares(address account, uint256 amount)
        internal
        override
    {
        require(account != address(0), "Mint to the zero address");
        debtSharesSupply += amount;
        _debtShares[account] += amount;
    }

    function _burnDebtShares(address account, uint256 amount)
        internal
        override
    {
        require(account != address(0), "Mint to the zero address");
        uint256 accountBalance = _debtShares[account];
        require(accountBalance >= amount, "Burn amount exceeds balance");
        unchecked {
            _debtShares[account] = accountBalance - amount;
        }
        debtSharesSupply -= amount;
    }
}
