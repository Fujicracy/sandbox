// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract Vault is ERC4626{

  constructor(address asset) ERC4626(IERC20Metadata(asset)) ERC20('shares Of Asset', 'shA') {
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal pure override {
    from;
    to;
    amount;
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal pure override {
    from;
    to;
    amount;
  }

}