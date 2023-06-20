// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {DiamondLoupeFacet} from "../../src/facets/diamond/DiamondLoupeFacet.sol";
import {DiamondCutFacet} from "../../src/facets/diamond/DiamondCutFacet.sol";
import {OwnershipFacet} from "../../src/facets/diamond/OwnershipFacet.sol";
import {IDiamond} from "../../src/interfaces/IDiamond.sol";

contract DiamondConstants is Test {
  DiamondLoupeFacet public loupe;
  DiamondCutFacet public cut;
  OwnershipFacet public ownership;
  address public init;
  address public diamond;

  bytes4[] public loupeSelectors;
  bytes4[] public cutSelectors;
  bytes4[] public ownershipSelectors;

  constructor() {
    bytes4[] memory loupeSelectors_ = new bytes4[](4);
    loupeSelectors_[0] = bytes4(DiamondLoupeFacet.facets.selector);
    loupeSelectors_[1] = bytes4(DiamondLoupeFacet.facetFunctionSelectors.selector);
    loupeSelectors_[2] = bytes4(DiamondLoupeFacet.facetAddresses.selector);
    loupeSelectors_[3] = bytes4(DiamondLoupeFacet.facetAddress.selector);

    loupeSelectors = loupeSelectors_;

    bytes4[] memory cutSelectors_ = new bytes4[](1);
    cutSelectors_[0] = bytes4(DiamondCutFacet.diamondCut.selector);

    cutSelectors = cutSelectors_;

    bytes4[] memory ownershipSelectors_ = new bytes4[](2);
    ownershipSelectors_[0] = bytes4(OwnershipFacet.transferOwnership.selector);
    ownershipSelectors_[1] = bytes4(OwnershipFacet.owner.selector);
    ownershipSelectors = ownershipSelectors_;
  }
}
