// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "./interfaces/ILendingProvider.sol";
import "./interfaces/IFujiOracle.sol";
import "./interfaces/IWETH.sol";

/**
 * @title XFuji Lending Vault.
 * @author fujidao Labs
 * @notice This contract manages pure lending in an ERC4626 implementation.
 */
contract LendingVault is ERC4626 {
    using Math for uint256;
    using Address for address;

    IWETH public immutable WRAPPED_NATIVE;

    ILendingProvider[] internal _providers;
    ILendingProvider public activeProvider;

    /**
     * @dev  Handle direct sending of native-token.
     */
    receive() external payable {
        IWETH(WRAPPED_NATIVE).deposit{value: msg.value}();
    }

    constructor(
        address asset,
        address wrappedNative_
    ) ERC4626(IERC20Metadata(asset)) ERC20("Flenda Vault Shares", "fVshs") {
        WRAPPED_NATIVE = IWETH(wrappedNative_);
    }

    ///////////////////////////////////////////////
    /// Asset management overrides from ERC4626 ///
    ///////////////////////////////////////////////

    /** @dev Overriden to check assets balance through providers {IERC4262-totalAssets}. */
    function totalAssets() public view virtual override returns (uint256) {
        return _computeTotalAssets();
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
        address onBehalf
    ) public override returns (uint256) {
        require(shares <= maxRedeem(onBehalf), "Redeem more than max");

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, onBehalf, assets, shares);

        return assets;
    }

    /// Token shares transfer hooks.

    /** @dev Implemented to avoid abstract contract definition. */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal pure override {}

    /** @dev Implemented to avoid abstract contract definition. */
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

    function _setMaxAllowances(ILendingProvider activeProvider_) internal {
        // max approve asset and debtAsset for active
        address asset = asset();
        address spender = activeProvider_.approveOperator(asset);
        SafeERC20.safeApprove(IERC20(asset), spender, type(uint256).max);
    }

    function _removeMaxAllowances(ILendingProvider oldActiveProvider_)
        internal
    {
        // remove max approve asset and debtAsset
        address asset = asset();
        address spender = oldActiveProvider_.approveOperator(asset);
        SafeERC20.safeApprove(IERC20(asset), spender, 0);
    }
}
