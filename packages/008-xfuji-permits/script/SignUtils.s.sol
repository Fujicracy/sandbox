// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";

contract SignUtils is Test {

  // transactionId=0x2810ed2ea4c2afe06adc8a61c520f4336f6b1a94ee84ba225c1f851d0f767146
  // Last digest_ = 0x18f1a6019ed46f9d5f1243af0d75fb7b546db37660f8a7ac5afe3aa066458be3, with deadline 1660704647
  bytes32 public digest;
  uint public pkey_;

  function run() public {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkey_, digest_);
    console.log("v",v);
    console.log("r");console.logBytes32(r);
    console.log("s"); console.logBytes32(s);
  }

}