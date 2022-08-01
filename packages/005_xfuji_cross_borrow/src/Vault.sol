// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Address.sol";
import "./interfaces/IProvider.sol";

contract Vault is ERC4626, Ownable {
  using Address for address;

  address public router;

  uint16 public maxLtv;
  uint16 public liqRatio;

  IProvider[] public providers;
  IProvider public activeProvider;

  constructor(
    address _asset,
    address _debtAsset,
    address _router,
    uint16 _maxLtv,
    uint16 _liqRatio,
    IProvider[] memory _providers
  ) 
    ERC4626(IERC20Metadata(_asset))
    ERC20(
      // ex: Fuji-X Dai Stablecoin Vault Shares
      string(abi.encodePacked("Fuji-X ", IERC20Metadata(_asset).name(), "-", IERC20Metadata(_debtAsset).name(), " Vault Shares")),
      // ex: fxDAI
      string(abi.encodePacked("fx", IERC20Metadata(_asset).symbol(), "-", IERC20Metadata(_debtAsset).symbol()))
    )
  {
    router = _router;
    maxLtv = _maxLtv;
    liqRatio = _liqRatio;

    setProviders(_providers);
    setActiveProvider(_providers[0]);
  }

  ///////////////////////////////////////////////
  /// Interactions from Router only ///
  ///////////////////////////////////////////////

  modifier onlyRouter() {
    require(msg.sender == router);
    _;
  }

  function deposit(uint256 assets, address receiver) public override onlyRouter returns (uint256) {
    return super.deposit(assets, receiver);
  }

  function mint(uint256 shares, address receiver) public override onlyRouter returns (uint256) {
    return super.mint(shares, receiver);
  }

  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public override onlyRouter returns (uint256) {
    return super.withdraw(assets, receiver, owner);
  }

  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) public override onlyRouter returns (uint256) {
    return super.redeem(shares, receiver, owner);
  }

  ///////////////////////////////////////////////
  /// Asset management overrides from ERC4626 ///
  ///////////////////////////////////////////////

  function totalAssets() public view override returns (uint256) {
    return activeProvider.getDepositBalance(asset(), address(this));
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
    address spender = activeProvider.approvedOperator(asset);
    SafeERC20.safeApprove(IERC20(asset), spender, assets);

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

  ///////////////////////////
  /// Admin set functions ///
  ///////////////////////////

  function setProviders(IProvider[] memory _providers) public onlyOwner {
    providers = _providers;
    //TODO event
  }

  function setActiveProvider(IProvider _activeProvider) public onlyOwner {
    activeProvider = _activeProvider;
    //TODO event
  }

  ///////////////////////////
  /// Internal functions ///
  ///////////////////////////

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
}
