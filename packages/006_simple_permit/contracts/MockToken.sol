// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "hardhat/console.sol";

contract MockToken is ERC20Permit {
    constructor() ERC20("MockToken", "MKT") ERC20Permit("MockToken") {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal override virtual {
        uint256 currentAllowance = allowance(owner, spender);
        console.log('amount', amount, 'currentAllowance', currentAllowance);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}