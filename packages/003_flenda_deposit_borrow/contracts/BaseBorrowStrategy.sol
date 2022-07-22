// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// TODO to be put in ./interfaces
interface IBorrowStrategy {
  function borrow(uint amount, address receiver) external returns (uint);

  // payback()
}

// TODO to be put in ./interfaces
interface IVault {
  function collateral() external returns (address);

  function depositTo(uint strategyId, uint amount, address onBehalf) external;

  function withdrawFrom(uint strategyId, uint amount, address onBehal) external;

  function borrowFrom(uint strategyId, uint amount, address onBehalf) external;

  // ...
}

abstract contract BaseBorrowStrategy is IBorrowStrategy, ERC4626 {
  using Math for uint256;

  IVault public immutable vault;
  IERC20Metadata public immutable debtAsset;

  uint public debtShares;
  uint public debtAmount;

  constructor(
    address vault_,
    address collateral_,
    address debtAsset_
  ) 
    ERC4626(IERC20Metadata(collateral_))
  {
    vault = IVault(vault_);
    require(collateral_ == vault.collateral(), "Incompatible vault and strategy");
    debtAsset = IERC20Metadata(debtAsset_);
  }

  // deposit, withdraw and harvest from the lending provider
  function deposit(
    uint assets,
    address receiver
  )
    public
    override
    returns (uint shares)
  {
    // no need to accrue
    // provider specific logic to deposit
    shares = super.deposit(assets, receiver);
  }

  function withdraw(
    uint assets,
    address receiver,
    address owner
  )
    public
    override
    returns (uint shares)
  {
    accrue();
    // provider specific logic to deposit
    shares = super.withdraw(assets, receiver, owner);
  }

  function borrow(
    uint amount,
    address receiver
  )
    public
    returns (uint shares)
  {
    // require calls only from vault
    accrue();
    // go with provider specific logic
    shares = _convertDebtToShares(amount);
    debtShares += shares;
    debtAmount += amount;

    // transfer amount to receiver
    receiver;
  }

  function payback(
    uint amount,
    address receiver
  )
    public
    returns (uint shares)
  {
    amount;
    receiver;
    accrue();
    shares;
    // go with provider specific logic
  }

  // Harvest any liquidity mining rewards and
  // convert to increase asset or decrease debtAsset.
  // function harvest(...) external;

  // Pull balances from provider to update debtAmount
  function accrue() public {
  }

  // Override totalAssets() to account for the interest accual
  function totalAssets() public view override returns (uint) {
  }

  function _convertDebtToShares(uint amount) internal view returns (uint256 shares) {
    return
      (amount == 0 || debtAmount == 0)
        ? amount.mulDiv(10**decimals(), 10**debtAsset.decimals(), Math.Rounding.Down)
        : amount.mulDiv(debtShares, debtAmount, Math.Rounding.Down);
  }
}
