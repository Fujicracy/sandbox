// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Constants, console} from "./utils/Constants.t.sol";
import {DiamondLoupeFacet} from "../src/facets/diamond/DiamondLoupeFacet.sol";
import {DiamondCutFacet} from "../src/facets/diamond/DiamondCutFacet.sol";
import {OwnershipFacet} from "../src/facets/diamond/OwnershipFacet.sol";
import {DiamondInit} from "../src/upgradeInitializers/DiamondInit.sol";
import {IDiamond} from "../src/interfaces/IDiamond.sol";
import {DiamondArgs, Diamond} from "../src/Diamond.sol";

contract Routines is Constants {
  DiamondLoupeFacet public loupe;
  DiamondCutFacet public cut;
  OwnershipFacet public ownership;
  address public init;
  address public diamond;

  function _deploySimpleDiamond() internal {
    loupe = new DiamondLoupeFacet();
    bytes4[] memory loupeSelectors = new bytes4[](4);
    loupeSelectors[0] = bytes4(DiamondLoupeFacet.facets.selector);
    loupeSelectors[1] = bytes4(DiamondLoupeFacet.facetFunctionSelectors.selector);
    loupeSelectors[2] = bytes4(DiamondLoupeFacet.facetAddresses.selector);
    loupeSelectors[3] = bytes4(DiamondLoupeFacet.facetAddress.selector);

    cut = new DiamondCutFacet();
    bytes4[] memory cutSelectors = new bytes4[](1);
    cutSelectors[0] = bytes4(DiamondCutFacet.diamondCut.selector);

    ownership = new OwnershipFacet();
    bytes4[] memory ownershipSelectors = new bytes4[](2);
    ownershipSelectors[0] = bytes4(OwnershipFacet.transferOwnership.selector);
    ownershipSelectors[1] = bytes4(OwnershipFacet.owner.selector);

    init = address(0);

    IDiamond.FacetCut[] memory coreFacets = new IDiamond.FacetCut[](3);

    coreFacets[0] = IDiamond.FacetCut(address(loupe), IDiamond.FacetCutAction.Add, loupeSelectors);
    coreFacets[1] = IDiamond.FacetCut(address(cut), IDiamond.FacetCutAction.Add, cutSelectors);
    coreFacets[2] =
      IDiamond.FacetCut(address(ownership), IDiamond.FacetCutAction.Add, ownershipSelectors);

    DiamondArgs memory args = DiamondArgs(ALICE, init, "0x00");

    diamond = address(new Diamond(coreFacets, args));
  }
}
