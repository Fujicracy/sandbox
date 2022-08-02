// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../AaveV3TestSuit.t.sol";

contract AaveV3Test is AaveV3TestSuit {
  constructor() AaveV3TestSuit(
    0xc4dCB5126a3AfEd129BC3668Ea19285A9f56D15D,
    0x2e3A2fb8473316A02b8A297B982498E661E1f6f5,
    0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43,
    0x6c9a905Ab3f4495E2b47f5cA131ab71281E0546e,
    0x26FE8a8f86511d678d031a022E48FfF41c6a3e3b
  ) {}
}
