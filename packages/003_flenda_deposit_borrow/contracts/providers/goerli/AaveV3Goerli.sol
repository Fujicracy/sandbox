// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "../../interfaces/ILendingProvider.sol";
import "../../interfaces/aaveV3/IAaveProtocolDataProvider.sol";
import "../../interfaces/aaveV3/IPool.sol";
// import "../../interfaces/IUnwrapper.sol";
// import "../../interfaces/IWETH.sol";
// import "../../libraries/UniversalERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AaveV3 Lending Provider.
 * @author fujidao Labs
 * @notice This contract allows interaction with AaveV3.
 */
contract AaveV3Goerli is ILendingProvider {
  // using UniversalERC20 for IERC20;

  function _getNativeAddr() internal pure returns (address) {
    return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  }

  function _getWrappedNativeAddr() internal pure returns (address) {
    return 0x2e3A2fb8473316A02b8A297B982498E661E1f6f5;
  }

  function _getAaveProtocolDataProvider() internal pure returns (IAaveProtocolDataProvider) {
    return IAaveProtocolDataProvider(0x9BE876c6DC42215B00d7efe892E2691C3bc35d10);
  }

  function _getPool() internal pure returns (IPool) {
    return IPool(0x368EedF3f56ad10b9bC57eed4Dac65B26Bb667f6);
  }

  function _getUnwrapper() internal pure returns (address) {
    return 0xBB73511B0099eF355AA580D0149AC4C679A0B805;
  }

  /**
  * @notice See {ILendingProvider} 
  */
  function approveOperator(address) external override pure returns(address operator) {
    operator = address(_getPool());
  }

  /**
  * @notice See {ILendingProvider} 
  */
  function deposit(address asset, uint256 amount) external override returns(bool success) {
    IPool aave = _getPool();
    // bool isNative = asset == _getNativeAddr();
    // address _tokenAddr = isNative ? _getWrappedNativeAddr() : asset;
    // convert Native to WrappedNative
    // if (isNative) IWETH(_tokenAddr).deposit{ value: amount }();
    // IERC20(_tokenAddr).univApprove(address(aave), amount);

    aave.supply(asset, amount, address(this), 0);

    aave.setUserUseReserveAsCollateral(asset, true);
    success = true;
  }

  /**
   * @notice See {ILendingProvider}  
   */
  function borrow(address asset, uint256 amount) external override returns(bool success) {
    IPool aave = _getPool();
    // bool isNative = asset == _getNativeAddr();
    // address _tokenAddr = isNative ? _getWrappedNativeAddr() : asset;
    aave.borrow(asset, amount, 2, 0, address(this));
    // convert Native to WrappedNative
    // if (isNative) {
    //   address unwrapper = _getUnwrapper();
    //   IERC20(_tokenAddr).univTransfer(payable(unwrapper), amount);
    //   IUnwrapper(unwrapper).withdraw(amount);
    // }
    success = true;
  }

  /**
   * @notice See {ILendingProvider} 
   */
  function withdraw(address asset, uint256 amount) external override returns(bool success) {
    IPool aave = _getPool();
    // bool isNative = asset == _getNativeAddr();
    // address _tokenAddr = isNative ? _getWrappedNativeAddr() : asset;
    aave.withdraw(asset, amount, address(this));
    // convert Native to WrappedNative
    // if (isNative) {
    //   address unwrapper = _getUnwrapper();
    //   IERC20(_tokenAddr).univTransfer(payable(unwrapper), amount);
    //   IUnwrapper(unwrapper).withdraw(amount);
    // }
    success = true;
  }

  /**
   * @notice See {ILendingProvider} 
   */
  function payback(address asset, uint256 amount) external override returns(bool success) {
    IPool aave = _getPool();
    // bool isNative = asset == _getNativeAddr();
    // address _tokenAddr = isNative ? _getWrappedNativeAddr() : asset;
    // convert Native to WrappedNative
    // if (isNative) IWETH(_tokenAddr).deposit{ value: amount }();
    // IERC20(_tokenAddr).univApprove(address(aave), amount);

    aave.repay(asset, amount, 2, address(this));

    success = true;
  }

  /**
   * @notice See {ILendingProvider} 
   */
  function getDepositRateFor(address asset) external override view returns (uint256 rate) {
    IPool aaveData = _getPool();
    IPool.ReserveData memory rdata = aaveData.getReserveData(
      asset == _getNativeAddr() ? _getWrappedNativeAddr() : asset
    );
    rate = rdata.currentLiquidityRate;
  }

  /**
   * @notice See {ILendingProvider}  
   */
  function getBorrowRateFor(address asset) external override view returns (uint256 rate) {
    IPool aaveData = _getPool();
    IPool.ReserveData memory rdata = aaveData.getReserveData(
      asset == _getNativeAddr() ? _getWrappedNativeAddr() : asset
    );
    rate = rdata.currentVariableBorrowRate;
  }

  /**
   * @notice See {ILendingProvider} 
   */
  function getDepositBalance(address asset, address user) external override view returns (uint256 balance){
    IAaveProtocolDataProvider aaveData = _getAaveProtocolDataProvider();
    bool isNative = asset == _getNativeAddr();
    address _tokenAddr = isNative ? _getWrappedNativeAddr() : asset;
    (balance, , , , , , , , ) = aaveData.getUserReserveData(_tokenAddr, user);
  }

  /**
   * @notice See {ILendingProvider} 
   */
  function getBorrowBalance(address asset, address user) external override view returns (uint256 balance) {
    IAaveProtocolDataProvider aaveData = _getAaveProtocolDataProvider();
    bool isNative = asset == _getNativeAddr();
    address _tokenAddr = isNative ? _getWrappedNativeAddr() : asset;
    (, , balance, , , , , , ) = aaveData.getUserReserveData(_tokenAddr, user);
  }
}