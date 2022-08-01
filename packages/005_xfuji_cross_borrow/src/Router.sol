// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "openzeppelin-contracts/access/Ownable.sol";
import "./interfaces/IVault.sol";
import "./interfaces/connext/IConnext.sol";
import "./interfaces/connext/ITest.sol";

contract Router is Ownable {
  IConnext public immutable connext;
  address public testToken;
  
  // connext domain id => xFuji Router address
  mapping(uint256 => address) public routerByDomain;

  // asset => vault
  mapping(address => address) public vaultByAsset;

  // vault => valid
  mapping(address => bool) public validVault;

  constructor(address _connext) {
    connext = IConnext(_connext);
  }

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

  function setTestToken(address _testToken) external onlyOwner {
    //TODO event
    testToken = _testToken;
  }

  ///////////////////////////
  /// Cross chain magic ///
  ///////////////////////////

  function bridgePosition(address asset, address assetTarget, uint256 amount, uint32 targetDomain) external {
    require(routerByDomain[targetDomain] != address(0));

    // Withdrawing posigion
    IVault(vaultByAsset[asset]).withdraw(amount, address(this), msg.sender);
    // We burn the token and mint $TEST because connext does not support bridigng other than $TEST
    //TODO BURN TOKEN
    ITest(testToken).mint(address(this), amount);


    // Bridging logic

    bytes4 selector = bytes4(keccak256("targetBridgePosition(address,uint256,uint32)"));
    bytes memory callData = abi.encodeWithSelector(selector, assetTarget, amount, uint32(connext.domain));

    IConnext.CallParams memory callParams = IConnext.CallParams({
      to: routerByDomain[targetDomain],
      callData: callData,
      originDomain: uint32(connext.domain()),
      destinationDomain: targetDomain,
      agent: routerByDomain[targetDomain], // address allowed to transaction on destination side in addition to relayers
      recovery: routerByDomain[targetDomain], // fallback address to send funds to if execution fails on destination side
      forceSlow: true, // option to force Nomad slow path (~30 mins) instead of paying 0.05% fee
      receiveLocal: false, // option to receive the local Nomad-flavored asset instead of the adopted asset
      callback: address(0), // this contract implements the callback
      callbackFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
      relayerFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
      slippageTol: 9995 // tolerate .05% slippage
    });

    IConnext.XCallArgs memory xcallArgs = IConnext.XCallArgs({
      params: callParams,
      transactingAssetId: testToken,
      amount: amount // no amount sent with this calldata-only xcall
    });

    connext.xcall(xcallArgs);
  }

  function targetBridgePosition(address asset, uint256 amount, uint32 originDomain) external {

  }

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
