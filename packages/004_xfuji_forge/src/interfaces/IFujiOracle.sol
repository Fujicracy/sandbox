// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

interface IFujiOracle {
  // FujiOracle Events

  /**
   * @dev Log a change in price feed address for asset address
   */
  event AssetPriceFeedChanged(address asset, address newPriceFeedAddress);

  function getPriceOf(
    address _collateralAsset,
    address _borrowAsset,
    uint8 _decimals
  ) external view returns (uint256);
}
