// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "./interfaces/ILendingProvider.sol";
import "./interfaces/IFujiOracle.sol";
import "./interfaces/IWETH.sol";

import "hardhat/console.sol";

contract Vault is ERC4626 {
    using Math for uint256;
    using Address for address;

    struct Factor {
        uint64 num;
        uint64 denum;
    }

    event Borrow(
        address indexed caller,
        address indexed owner,
        uint256 debt,
        uint256 shares
    );

    event Payback(
        address indexed caller,
        address indexed owner,
        uint256 debt,
        uint256 shares
    );

    IWETH public immutable WRAPPED_NATIVE;

    IERC20Metadata internal immutable _debtAsset;

    uint256 public debtSharesSupply;

    mapping(address => uint256) internal _debtShares;

    ILendingProvider[] internal _providers;
    ILendingProvider public activeProvider;

    IFujiOracle public oracle;

    Factor public maxLtv;

    Factor public liqRatio;

    /**
     * @dev  Handle direct sending of native-token.
     */
    receive() external payable {
        IWETH(WRAPPED_NATIVE).deposit{value: msg.value}();
    }

    constructor(
        address asset,
        address debtAsset_,
        address fujiOracle,
        address wrappedNative_
    ) ERC4626(IERC20Metadata(asset)) ERC20("Flenda Vault Shares", "fVshs") {
        _debtAsset = IERC20Metadata(debtAsset_);
        oracle = IFujiOracle(fujiOracle);
        WRAPPED_NATIVE = IWETH(wrappedNative_);
        maxLtv.num = 75;
        maxLtv.denum = 100;
        liqRatio.num = 80;
        liqRatio.denum = 100;
    }

    ///////////////////////////////////////////////
    /// Asset management overrides from ERC4626 ///
    ///////////////////////////////////////////////

    /** @dev Overriden to check assets balance through providers {IERC4262-totalAssets}. */
    function totalAssets() public view virtual override returns (uint256) {
        return _computeTotalAssets();
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
        // TODO Need to add security to onBehalf !!!!!!!!
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
        address onBehalf
    ) public override returns (uint256) {
        require(shares <= maxRedeem(onBehalf), "Redeem more than max");

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, onBehalf, assets, shares);

        return assets;
    }

    /// Token transfer hooks.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal view override {
        to;
        if (from != address(0)) {
            require(amount <= maxRedeem(from), "Transfer more than max");
        }
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal pure override {}

    /** @dev Overriden to perform _deposit adding flow at lending provider {IERC4626-deposit}. */
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
        SafeERC20.safeTransferFrom(
            IERC20(asset),
            caller,
            address(this),
            assets
        );
        // address spender = activeProvider.approveOperator(asset);
        // SafeERC20.safeApprove(IERC20(asset), spender, assets);
        bytes memory sendData = abi.encodeWithSelector(
            activeProvider.deposit.selector,
            asset,
            assets
        );
        _providerCall(sendData, "Deposit: call failed");
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
        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transfered, which is a valid state.
        _burn(owner, shares);
        address asset = asset();
        bytes memory sendData = abi.encodeWithSelector(
            activeProvider.withdraw.selector,
            asset,
            assets
        );
        _providerCall(sendData, "Withdraw: call failed");
        SafeERC20.safeTransfer(IERC20(asset), receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    ///////////////////////////////////////////////////////////
    /// Debt shares management; functions based on ERC4626. ///
    ///////////////////////////////////////////////////////////

    /** @dev Inspired on {IERC20Metadata-decimals}. */
    function debtDecimals() public view returns (uint8) {
        return decimals();
    }

    /** @dev Based on {IERC4626-asset}. */
    function debtAsset() public view returns (address) {
        return address(_debtAsset);
    }

    /** @dev Based on {IERC4626-totalAssets}. */
    function totalDebt() public view returns (uint256) {
        return _computeTotalDebt();
    }

    /** @dev Based on {IERC4626-convertToShares}. */
    function convertDebtToShares(uint256 debt)
        public
        view
        returns (uint256 shares)
    {
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
    function payback(uint256 debt, address onBehalf)
        public
        virtual
        returns (uint256)
    {
        require(debt > 0, "Wrong input");
        require(
            debt <= convertToDebt(_debtShares[onBehalf]),
            "Payback more than max"
        );

        uint256 shares = convertDebtToShares(debt);
        _payback(_msgSender(), onBehalf, debt, shares);

        return shares;
    }

    function _computeTotalAssets() internal view returns (uint256 assets) {
        address asset = asset();
        uint256 pLenght = _providers.length;
        for (uint256 i = 0; i < pLenght; ) {
            assets += _providers[i].getDepositBalance(asset, address(this));
            unchecked {
                ++i;
            }
        }
    }

    function _computeTotalDebt() internal view returns (uint256 debt) {
        address debtAsset_ = debtAsset();
        uint256 pLenght = _providers.length;
        for (uint256 i = 0; i < pLenght; ) {
            debt += _providers[i].getBorrowBalance(debtAsset_, address(this));
            unchecked {
                ++i;
            }
        }
    }

    function _computeMaxBorrow(address borrower)
        internal
        view
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
        returns (uint256 freeAssets)
    {
        uint256 debtShares = _debtShares[owner];
        bool noDebt = debtShares > 0 ? false : true;
        if (noDebt) {
            freeAssets = _convertToAssets(balanceOf(owner), Math.Rounding.Down);
        } else {
            uint256 debt = convertToDebt(debtShares);
            uint256 price = oracle.getPriceOf(
                asset(),
                debtAsset(),
                IERC20Metadata(asset()).decimals()
            );
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
        virtual
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
        address onBehalf,
        uint256 debt,
        uint256 shares
    ) internal {
        _mintDebtShares(onBehalf, shares);
        bytes memory sendData = abi.encodeWithSelector(
            activeProvider.borrow.selector,
            debtAsset(),
            debt
        );
        _providerCall(sendData, "Borrow: call failed");

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
        // address spender = activeProvider.approveOperator(debtAsset());
        // SafeERC20.safeApprove(_debtAsset, spender, debt);
        bytes memory sendData = abi.encodeWithSelector(
            activeProvider.payback.selector,
            debtAsset(),
            debt
        );
        _providerCall(sendData, "Payback: call failed");
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

    function _providerCall(bytes memory data, string memory errorMsg) private {
        bytes memory returndata = address(activeProvider).functionDelegateCall(
            data,
            errorMsg
        );
        require(
            abi.decode(returndata, (bool)),
            "LendingProvider: operation did not succeed"
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
        if (address(activeProvider) != address(0)) {
            _removeMaxAllowances(activeProvider);
        }
        activeProvider = activeProvider_;
        _setMaxAllowances(activeProvider);
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

    function _setMaxAllowances(ILendingProvider activeProvider_) internal {
        // max approve asset and debtAsset for active
        address asset = asset();
        address spender = activeProvider_.approveOperator(asset);
        SafeERC20.safeApprove(IERC20(asset), spender, type(uint256).max);

        address debt = debtAsset();
        spender = activeProvider_.approveOperator(debt);
        SafeERC20.safeApprove(IERC20(debt), spender, type(uint256).max);
    }

    function _removeMaxAllowances(ILendingProvider oldActiveProvider_)
        internal
    {
        // remove max approve asset and debtAsset
        address asset = asset();
        address spender = oldActiveProvider_.approveOperator(asset);
        SafeERC20.safeApprove(IERC20(asset), spender, 0);

        address debt = debtAsset();
        spender = oldActiveProvider_.approveOperator(debt);
        SafeERC20.safeApprove(IERC20(debt), spender, 0);
    }
}
