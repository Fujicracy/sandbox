// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {IERC20, ERC20} from "../../../src/libraries/openzeppelin/ERC20.sol";

contract MockERC20 is ERC20 {
  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }

  /**
   * @dev Destroys `amount` tokens from the caller.
   *
   * See {ERC20-_burn}.
   */
  function burn(uint256 amount) public {
    _burn(_msgSender(), amount);
  }
}
