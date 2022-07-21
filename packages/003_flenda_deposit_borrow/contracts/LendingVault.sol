// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "./interfaces/ILendingProvider.sol";

contract LendingVault is ERC4626 {
    using Math for uint256;

    ILendingProvider[] internal _providers;
    ILendingProvider public activeProvider;

    constructor(address asset)
        ERC4626(IERC20Metadata(asset))
        ERC20("Flenda Vault Shares", "fVshs")
    {
    }

    /// Token transfer hooks.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal pure override {
        // Check if user has debtShares
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
