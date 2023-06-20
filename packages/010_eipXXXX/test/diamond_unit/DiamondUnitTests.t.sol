// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Routines, console} from "../Routines.t.sol";
import {IDiamond} from "../../src/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "../../src/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {OwnershipFacet} from "../../src/facets/diamond/OwnershipFacet.sol";

contract DiamondUnitTests is Routines {
  function setUp() public {
    _deploySimpleDiamond();
  }

  function test_numberOfFacets() public {
    IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(diamond).facets();
    assertEq(facets.length, 3);
  }

  function test_diamondLoupeExpectedSelectors() public {
    bytes4[] memory readSelectors = IDiamondLoupe(diamond).facetFunctionSelectors(address(loupe));
    bytes4[] memory expectedSelectors = new bytes4[](4);
    expectedSelectors[0] = bytes4(IDiamondLoupe.facets.selector);
    expectedSelectors[1] = bytes4(IDiamondLoupe.facetFunctionSelectors.selector);
    expectedSelectors[2] = bytes4(IDiamondLoupe.facetAddresses.selector);
    expectedSelectors[3] = bytes4(IDiamondLoupe.facetAddress.selector);
    assertEq(readSelectors.length, expectedSelectors.length);
    assertEq(readSelectors[0], expectedSelectors[0]);
    assertEq(readSelectors[1], expectedSelectors[1]);
    assertEq(readSelectors[2], expectedSelectors[2]);
    assertEq(readSelectors[3], expectedSelectors[3]);
  }

  function test_diamondCutExpectedSelectors() public {
    bytes4[] memory readSelectors = IDiamondLoupe(diamond).facetFunctionSelectors(address(cut));
    bytes4[] memory expectedSelectors = new bytes4[](1);
    expectedSelectors[0] = bytes4(IDiamondCut.diamondCut.selector);
    assertEq(readSelectors.length, expectedSelectors.length);
    assertEq(readSelectors[0], expectedSelectors[0]);
  }

  function test_ownershipExpectedSelectors() public {
    bytes4[] memory readSelectors = IDiamondLoupe(diamond).facetFunctionSelectors(address(ownership));
    bytes4[] memory expectedSelectors = new bytes4[](2);
    expectedSelectors[0] = bytes4(OwnershipFacet.transferOwnership.selector);
    expectedSelectors[1] = bytes4(OwnershipFacet.owner.selector);
    assertEq(readSelectors.length, expectedSelectors.length);
    assertEq(readSelectors[0], expectedSelectors[0]);
    assertEq(readSelectors[1], expectedSelectors[1]);
  }

  function test_gettingAllFacetAddresses() public {
    address[] memory facetsAddr = IDiamondLoupe(diamond).facetAddresses();
    assertEq(facetsAddr.length, 3);
    assertEq(facetsAddr[0], address(loupe));
    assertEq(facetsAddr[1], address(cut));
    assertEq(facetsAddr[2], address(ownership));
  }

  function test_getCorrectFacetAddressForSelector() public {
    IDiamondLoupe loupe_ = IDiamondLoupe(diamond);
    assertEq(loupe_.facetAddress(IDiamondLoupe.facets.selector), address(loupe));
    assertEq(loupe_.facetAddress(IDiamondLoupe.facetFunctionSelectors.selector), address(loupe));
    assertEq(loupe_.facetAddress(IDiamondLoupe.facetAddresses.selector), address(loupe));
    assertEq(loupe_.facetAddress(IDiamondLoupe.facetAddress.selector), address(loupe));
    assertEq(loupe_.facetAddress(IDiamondCut.diamondCut.selector), address(cut));
    assertEq(loupe_.facetAddress(OwnershipFacet.transferOwnership.selector), address(ownership));
    assertEq(loupe_.facetAddress(OwnershipFacet.owner.selector), address(ownership));
  }

  function test_whoIsOwner() public {
    address returnedOwner = OwnershipFacet(diamond).owner();
    assertEq(returnedOwner, ALICE);
  }
}
