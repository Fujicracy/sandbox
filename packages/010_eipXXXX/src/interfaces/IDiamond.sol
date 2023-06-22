// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

/**
 * @author Nick Mudge (https://twitter.com/mudgen)
 * @notice EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 */

interface IDiamond {
  enum FacetCutAction {
    Add,
    Replace,
    Remove
  }
  // Add=0, Replace=1, Remove=2

  struct FacetCut {
    address facetAddress;
    FacetCutAction action;
    bytes4[] functionSelectors;
  }

  event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}
