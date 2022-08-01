// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

interface IVault {
  function deposit(uint256 assets, address receiver) external returns (uint256);

  function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);

  function mint(uint256 shares, address receiver) external returns (uint256);

  function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
}
