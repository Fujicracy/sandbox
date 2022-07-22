// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "./interfaces/IFujiOracle.sol";

// TODO to be put in ./interfaces
interface IRegistry {
  function getRouter() external returns (address);
}

// TODO to be put in ./interfaces
interface IBorrowStrategy {
  function borrow(uint amount, address receiver) external returns (uint);

  // payback()
}

contract FujiVault {
  struct StrategyDetails {
    uint id;
    uint chainId;
    address addr;
    string name;
    bool lendingOnly;
  }

  struct Position {
    uint id;
    uint strategyId;
    uint collateralShares;
    uint debtShares;
  }

  StrategyDetails[] public strategies;
  StrategyDetails public fallbackStrategy;

  IERC20 public immutable collateral;

  IFujiOracle public oracle;
  IRegistry public registry;

  mapping(uint => StrategyDetails) public strategyById;

  mapping(address => mapping(uint => Position)) public userPositionByStrategy;
  mapping(address => Position[]) public userPositions;

  constructor(IRegistry registry_, IERC20 collateral_) {
    registry = registry_;
    collateral = collateral_;
  }

  modifier authRouterOrSelf(address onBehalf) {
    require(msg.sender == registry.getRouter() || msg.sender == onBehalf);
    _;
  }

  function depositTo(
    uint strategyId,
    uint amount,
    address onBehalf
  )
    external
    authRouterOrSelf(onBehalf)
  {
    // if strategyId == 0 default to fallbackStrategy
    // get strategy by strategyId or fallbackStrategy
    StrategyDetails memory strategy =
      strategyId != 0 ? strategyById[strategyId] : fallbackStrategy;

    Position memory position = userPositionByStrategy[onBehalf][strategy.id];

    // if position.id == 0 => create a new position and push to userPositions

    // next deposit to strategy to deploy the capital and get shares
    uint shares = ERC4626(strategy.addr).deposit(amount, address(this));
    // update user position
    position.collateralShares += shares;
  }

  function withdrawFrom(
    uint strategyId,
    uint amount,
    address onBehalf
  )
    external
    authRouterOrSelf(onBehalf)
  {
    // it's more convient to require to specify the strategy from which to withdraw
    // because user can have deposited to several strategies
    require(strategyId != 0);

    StrategyDetails memory strategy =
      strategyId != 0 ? strategyById[strategyId] : fallbackStrategy;

    Position memory position = userPositionByStrategy[onBehalf][strategy.id];

    uint collateralShares = ERC4626(strategy.addr).withdraw(amount, onBehalf, address(this));
    // get position
    // if position has debtShares, calulate if enough collateral is left to cover the debt
    require(collateralShares >= position.collateralShares);
    position.collateralShares -= collateralShares;
  }

  function borrowFrom(
    uint strategyId,
    uint amount,
    address onBehalf
  )
    external
    authRouterOrSelf(onBehalf)
  {
    // get strategy and position, see depositTo()
    StrategyDetails memory strategy =
      strategyId != 0 ? strategyById[strategyId] : fallbackStrategy;

    Position memory position = userPositionByStrategy[onBehalf][strategy.id];
    // require strategy is not lendingOnly
    // require user has enough collateral in strategy to borrow
    uint shares = IBorrowStrategy(strategy.addr).borrow(amount, onBehalf);
    position.debtShares += shares;
  }

  function paybackTo(
    uint strategyId,
    uint amount,
    address onBehalf
  )
    external
    authRouterOrSelf(onBehalf)
  {
  }

  function addStrategy(StrategyDetails calldata strategy) external {
    // require owner only
    // require ERC4626(strategy).asset == collateralAsset
    // and address(this) == strategy.vault;
  }
}
