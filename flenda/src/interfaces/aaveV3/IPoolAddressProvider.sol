// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

interface IPoolAddressProvider {
  function getPoolDataProvider() external view returns (address);
  function getPool() external view returns (address);
}