// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {AppStorage, LibVaultLogic} from "../libraries/LibVaultStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IERC20, IERC20Metadata} from "../interfaces/IERC20Metadata.sol";
import {IERC4626} from "../interfaces/IERC4626.sol";
import {IChief} from "../interfaces/IChief.sol";

contract VaultYieldInit {
  AppStorage internal s;

  function init(address asset, address chief, string memory name, string memory symbol) external {
    // adding ERC165 data
    LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
    ds.supportedInterfaces[type(IERC165).interfaceId] = true;
    ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
    ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
    ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    ds.supportedInterfaces[type(IERC20Metadata).interfaceId] = true;
    ds.supportedInterfaces[type(IERC4626).interfaceId] = true;

    // YieldVault state variables
    // TODO add all checks to inputs
    s.properties.asset = IERC20(asset);
    s.extAddresses.chief = IChief(chief);
    s.properties.vaultName = name;
    s.properties.vaultSymbol = symbol;
    // EIP-2535 specifies that the `diamondCut` function takes two optional
    // arguments: address _init and bytes calldata _calldata
    // These arguments are used to execute an arbitrary function using delegatecall
    // in order to set state variables in the diamond during deployment or an upgrade
    // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface
  }
}
