// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "openzeppelin-contracts/access/Ownable.sol";
import "./interfaces/IVault.sol";

contract Router is Ownable {
  
  // connext domain id => xFuji Router address
  mapping(uint256 => address) public routerByDomain;

  // asset => vault
  mapping(address => address) public vaultByAsset;

  // vault => valid
  mapping(address => bool) public validVault;

  ///////////////////////////
  /// Admin functions ///
  ///////////////////////////

  function addVault(address vault) external onlyOwner {
    //TODO event
    validVault[vault] = true;
    vaultByAsset[IVault(vault).asset()] = vault;
  }

  function addRouter(uint256 domain, address router) external onlyOwner {
    //TODO event
    routerByDomain[domain] = router;
  }

  ///////////////////////////
  /// Cross chain magic ///
  ///////////////////////////
  /*function bridgePosition()*/

  ///////////////////////////
  /// Vault interactions ///
  ///////////////////////////

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

  ///////////////////////////
  /// Internal functions ///
  ///////////////////////////

  function _isValidVault(IVault vault) internal view returns (bool isValid) {
    isValid = validVault[address(vault)];
  }
}
