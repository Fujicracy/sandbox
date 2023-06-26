// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import {SystemRoutines} from "../SystemRoutines.t.sol";
import {DiamondRoutines} from "../DiamondRoutines.t.sol";
import {IVault} from "../../src/interfaces/IVault.sol";
import {a16zERC4626TestSuite} from "./a16_erc4626_tests/a16zERC4626TestSuite.t.sol";

contract ERC4626UnitTests is DiamondRoutines, SystemRoutines, a16zERC4626TestSuite {
  address public vault_;

  function setUp() public override {
    _underlying_ = tWETH;
    _vault_ = _deployDiamondYieldVault(tWETH, chief, "Fuji-V2 tWETH YieldVault", "fyvtWETH");
    _delta_ = 0;
    _vaultMayBeEmpty = true;
    _unlimitedAmount = false;
  }

  // function test_verySimple() public {
  //   console.log("IVault(vault_).asset()", IVault(vault_).asset());
  // }
}
