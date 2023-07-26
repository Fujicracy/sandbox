// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import {DiamondLoupeFacet} from "../../src/facets/diamond/DiamondLoupeFacet.sol";
import {SystemRoutines} from "../SystemRoutines.t.sol";
import {DiamondRoutines} from "../DiamondRoutines.t.sol";
import {IVault} from "../../src/interfaces/IVault.sol";
import {ERC4626Prop, IERC4626, IERC20, IMockERC20} from "./ERC4626Prop.t.sol";
// import {a16zERC4626TestSuite} from "./a16_erc4626_tests/a16zERC4626TestSuite.t.sol";

contract ERC4626UnitTests is DiamondRoutines, SystemRoutines, ERC4626Prop {
  address public vault_;

  uint256 internal constant ALICE_PK = 0xA;
  address internal ALICE = vm.addr(ALICE_PK);

  uint256 internal constant PRECISION = 1e18;

  enum Yield {
    Gain,
    Loss
  }

  struct Init {
    address user;
    uint128 share;
    uint128 asset;
    uint128 yield;
    Yield sign;
  }

  function setUp() public {
    console.log("hello moto");
    _underlying_ = tWETH;
    _vault_ = _deployDiamondYieldVault(tWETH, chief, "Fuji-V2 tWETH YieldVault", "fyvtWETH");
    _delta_ = 0;
    _vaultMayBeEmpty = true;
    _unlimitedAmount = false;

    vm.label(ALICE, "alice");

    _VaultInit();
  }

  // function validateInit(Init memory init) internal view {
  //   vm.assume(
  //     init.user != address(0) && init.user != address(this) && init.share > 0 && init.asset > 0
  //   );
  //   init.yield = uint128(bound(init.yield, 0, PRECISION));
  // }

  // function setUpVault(Init memory init) public virtual {
  //   validateInit(init);
  //   // setup initial shares and assets for individual users
  //   address user = init.user;

  //   // shares
  //   uint256 shares = init.share;
  //   IMockERC20(_underlying_).mint(user, shares);
  //   _approve(_underlying_, user, _vault_, shares);
  //   vm.prank(user);
  //   IERC4626(_vault_).deposit(shares, user);

  //   // assets
  //   uint256 assets = init.asset;
  //   IMockERC20(_underlying_).mint(user, assets);

  //   // setup initial yield for vault
  //   setUpYield(init);
  // }

  // // setup initial yield
  // function setUpYield(Init memory init) public virtual {
  //   if (init.sign == Yield.Gain) {
  //     // gain
  //     uint256 gain = (init.share * init.yield) / PRECISION;
  //     IMockERC20(_underlying_).mint(_vault_, gain);
  //   } else {
  //     // loss
  //     uint256 loss = (init.share * (PRECISION - init.yield)) / PRECISION;
  //     if (loss != 0) {
  //       IMockERC20(_underlying_).burn(_vault_, loss);
  //     }
  //   }
  // }

  //
  // asset
  //
  function test_asset(address caller) public {
    prop_asset(caller);
  }

  function test_totalAssets(address caller) public {
    prop_totalAssets(caller);
  }

  //
  // convert
  //
  function test_convertToShares(address caller1, address caller2, uint256 assets) public {
    prop_convertToShares(caller1, caller2, assets);
  }

  function test_convertToAssets(address caller1, address caller2, uint256 shares) public {
    prop_convertToAssets(caller1, caller2, shares);
  }

  //
  // utils
  //
  function _VaultInit() internal {
    Init memory init;
    init.user = ALICE;
    init.share = 1e18;
    IMockERC20(_underlying_).mint(ALICE, init.share);
    _approve(_underlying_, ALICE, _vault_, init.share);

    address[] memory addr = DiamondLoupeFacet(_vault_).facetAddresses();

    console.log("addr");
    for (uint256 i = 0; i < addr.length; i++) {
      console.log(addr[i]);
    }

    console.log(
      "DiamondLoupeFacet(_vault_).facetAddress(IERC4626.deposit.selector)",
      DiamondLoupeFacet(_vault_).facetAddress(IERC4626.deposit.selector)
    );
    vm.prank(ALICE);
    IERC4626(_vault_).deposit(init.share, ALICE);
  }

  function _isContract(address account) internal view returns (bool) {
    return account.code.length > 0;
  }

  function _isEOA(address account) internal view returns (bool) {
    return account.code.length == 0;
  }

  function _approve(address token, address owner, address spender, uint256 amount) internal {
    vm.prank(owner);
    _safeApprove(token, spender, 0);
    vm.prank(owner);
    _safeApprove(token, spender, amount);
  }

  function _safeApprove(address token, address spender, uint256 amount) internal {
    (bool success, bytes memory retdata) =
      token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
    vm.assume(success);
    if (retdata.length > 0) vm.assume(abi.decode(retdata, (bool)));
  }

  function _max_deposit(address from) internal virtual returns (uint256) {
    if (_unlimitedAmount) return type(uint256).max;
    return IERC20(_underlying_).balanceOf(from);
  }

  function _max_mint(address from) internal virtual returns (uint256) {
    if (_unlimitedAmount) return type(uint256).max;
    return vault_convertToShares(IERC20(_underlying_).balanceOf(from));
  }

  function _max_withdraw(address from) internal virtual returns (uint256) {
    if (_unlimitedAmount) return type(uint256).max;
    return vault_convertToAssets(IERC20(_vault_).balanceOf(from)); // may be different from maxWithdraw(from)
  }

  function _max_redeem(address from) internal virtual returns (uint256) {
    if (_unlimitedAmount) return type(uint256).max;
    return IERC20(_vault_).balanceOf(from); // may be different from maxRedeem(from)
  }
}
