// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {AppStorage} from "./../../libraries/LibVaultStorage.sol";

contract VaultBase {
  AppStorage internal s;

  /**
   * @dev Returns the name of the tokenized vault.
   */
  function name() public view virtual override returns (string memory) {
    return s.vaultName;
  }

  /**
   * @dev Returns the symbol of the vault's token, usually a shorter version of the
   * name.
   */
  function symbol() public view virtual override returns (string memory) {
    return s.vaultSymbol;
  }
}
