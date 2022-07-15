// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

interface IWETH {
  function approve(address, uint256) external;

  function deposit() external payable;

  function withdraw(uint256) external;
}
