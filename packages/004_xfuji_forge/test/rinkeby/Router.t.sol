// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {RouterTestsSuit} from "../RouterTestsSuit.sol";

contract RouterTest is RouterTestsSuit {

  function setUp() public {
    vm.selectFork(rinkebyFork);
    deploy(1111);
  }
}
