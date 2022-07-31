// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VaultTestsSuit} from "../VaultTestsSuit.sol";

contract VaultTest is VaultTestsSuit {

  function setUp() public {
    vm.selectFork(rinkebyFork);
    deploy(1111);
  }
}