// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface ITest is IERC20 {
  function mint(address account, uint256 amount) external;

  function burn(address account, uint256 amount) external;
}
