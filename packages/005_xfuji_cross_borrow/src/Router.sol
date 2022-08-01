// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "openzeppelin-contracts/access/Ownable.sol";
import "./interfaces/IVault.sol";

contract Router is Ownable {
  IVault[] vaults;

  function addVault(address vault) external onlyOwner {
    //TODO event
    vaults.push(IVault(vault));
  }

  function deposit(IVault vault, uint256 assets) external {
    require(_isValidVault(vault), "Invalid vault");
    vault.deposit(assets, msg.sender);
  }

  function mint(IVault vault, uint256 shares) external {
    require(_isValidVault(vault), "Invalid vault");
    vault.mint(shares, msg.sender);
  }

  function withdraw(IVault vault, uint256 assets) external {
    require(_isValidVault(vault), "Invalid vault");
    vault.withdraw(assets, msg.sender, msg.sender);
  }

  function redeem(IVault vault, uint256 shares) external {
    require(_isValidVault(vault), "Invalid vault");
    vault.redeem(shares, msg.sender, msg.sender);
  }

  function _isValidVault(IVault vault) internal view returns (bool isValid) {
    isValid = false;
    for (uint256 i = 0; i < vaults.length; i++) {
      if (vaults[i] == vault) {
        isValid = true;
        break;
      }
    }
  }
}
