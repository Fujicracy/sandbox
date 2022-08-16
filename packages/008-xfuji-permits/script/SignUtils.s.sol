// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";

contract SignUtils is Test {

  // transactionId = 0x2810ed2ea4c2afe06adc8a61c520f4336f6b1a94ee84ba225c1f851d0f767146
  // Last digest_ = 0x18f1a6019ed46f9d5f1243af0d75fb7b546db37660f8a7ac5afe3aa066458be3, with deadline 1660704647
  // transactionId = 0x8873ec430165441d25ebb7daf8b9219dee563b49a4c1ea80549f260347bd0c00
  // Last digest_ = 0xa76bdeb5f4ad89e2f8d4f67cab8f2df378c85b0927bec63da4ce6a0ef41f227d, with deadline 1660743753
  bytes32 public digest_;
  uint public pkey_;

  function run() public {
    pkey_ = vm.envUint('PRIVATE_KEY_TEST');
    digest_ = vm.envBytes32('LAST_DIGEST');
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkey_, digest_);
    console.log("v",v);
    console.log("r");console.logBytes32(r);
    console.log("s"); console.logBytes32(s);
  }

}