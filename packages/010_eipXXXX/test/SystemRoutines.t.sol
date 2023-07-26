// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {Chief} from "../src/Chief.sol";
import {IERC20, MockERC20} from "./utils/mocks/MockERC20.sol";
import {MockProvider} from "./utils/mocks/MockProvider.sol";

contract SystemRoutines is Test {
  address public chief;
  address public timelock;
  address public addrMapper;
  address public tWETH;
  address public mockProvider;

  constructor() {
    chief = address(new Chief(true, true));
    timelock = address(Chief(chief).timelock());
    addrMapper = address(Chief(chief).addrMapper());
    tWETH = address(new MockERC20("Test Weth", "tWETH"));
    mockProvider = address(new MockProvider());

    vm.label(chief, "chief");
    vm.label(timelock, "timelock");
    vm.label(addrMapper, "addrMapper");
    vm.label(tWETH, "tWETH");
    vm.label(mockProvider, "mockProvider");
  }
}
