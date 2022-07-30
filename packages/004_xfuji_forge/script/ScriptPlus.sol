// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract ScriptPlus is Script {

  function saveAddress(string memory path, address addr) internal {
    try vm.removeFile(path) {
    } catch {
      console.log(string(abi.encodePacked("Creating a new record at ", path)));
    }
    vm.writeLine(path, vm.toString(addr));
  }
}
