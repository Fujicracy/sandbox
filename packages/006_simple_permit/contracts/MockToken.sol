// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract MockToken is ERC20Permit {
    constructor() ERC20("MockToken", "MKT") ERC20Permit("MockToken") {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }
}