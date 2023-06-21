// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {DiamondRoutines} from "../DiamondRoutines.t.sol";
import {a16zERC4626TestSuite} from "./a16_erc4626_tests/a16zERC4626TestSuite.t.sol";

contract ERC4626UnitTests is a16zERC4626TestSuite, DiamondRoutines {
  function setUp() public override {}
}
