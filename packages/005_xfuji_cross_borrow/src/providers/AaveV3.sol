// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "../interfaces/IProvider.sol";
import "../interfaces/aavev3/IPoolAddressProvider.sol";
import "../interfaces/aaveV3/IAaveProtocolDataProvider.sol";
import "../interfaces/aaveV3/IPool.sol";

/**
* @title AaveV3 Lending Provider.
* @author fujidao Labs
* @notice This contract allows interaction with AaveV3.
*/
contract AaveV3 is IProvider { 
  IPoolAddressProvider addressProvider;

  constructor(address _addressProvider) {
    addressProvider = IPoolAddressProvider(_addressProvider);
  }

  function _getPool() internal view returns (IPool) {
    return IPool(addressProvider.getPool());
  }

  function _getAaveProtocolDataProvider() internal view returns (IAaveProtocolDataProvider) {
    return IAaveProtocolDataProvider(addressProvider.getPoolDataProvider());
  }

  /**
  * @notice See {IProvider}
  */
  function approvedOperator(address)
    external
    view
    override
    returns (address operator)
  {
    operator = address(_getPool());
  }

  /**
  * @notice See {IProvider}
  */
  function deposit(address asset, uint256 amount)
    external
    override
    returns (bool success)
  {
    IPool aave = _getPool();
    aave.supply(asset, amount, address(this), 0);
    aave.setUserUseReserveAsCollateral(asset, true);
    success = true;
  }

  /**
  * @notice See {IProvider}
  */
  function borrow(address asset, uint256 amount)
    external
    override
    returns (bool success)
  {
    IPool aave = _getPool();
    aave.borrow(asset, amount, 2, 0, address(this));
    success = true;
  }

  /**
  * @notice See {IProvider}
  */
  function withdraw(address asset, uint256 amount)
    external
    override
    returns (bool success)
  {
    IPool aave = _getPool();
    aave.withdraw(asset, amount, address(this));
    success = true;
  }

  /**
  * @notice See {IProvider}
  */
  function payback(address asset, uint256 amount)
    external
    override
    returns (bool success)
  {
    IPool aave = _getPool();
    aave.repay(asset, amount, 2, address(this));
    success = true;
  }

  /**
  * @notice See {IProvider}
  */
  function getDepositRateFor(address asset)
    external
    view
    override
    returns (uint256 rate)
  {
    IPool aaveData = _getPool();
    IPool.ReserveData memory rdata = aaveData.getReserveData(asset);
    rate = rdata.currentLiquidityRate;
  }

  /**
  * @notice See {IProvider}
  */
  function getBorrowRateFor(address asset)
    external
    view
    override
    returns (uint256 rate)
  {
    IPool aaveData = _getPool();
    IPool.ReserveData memory rdata = aaveData.getReserveData(asset);
    rate = rdata.currentVariableBorrowRate;
  }

  /**
  * @notice See {IProvider}
  */
  function getDepositBalance(address asset, address user)
    external
    view
    override
    returns (uint256 balance)
  {
    IAaveProtocolDataProvider aaveData = _getAaveProtocolDataProvider();
    (balance, , , , , , , , ) = aaveData.getUserReserveData(asset, user);
  }

  /**
  * @notice See {IProvider}
  */
  function getBorrowBalance(address asset, address user)
    external
    view
    override
    returns (uint256 balance)
  {
    IAaveProtocolDataProvider aaveData = _getAaveProtocolDataProvider();
    (, , balance, , , , , , ) = aaveData.getUserReserveData(asset, user);
  }
}
