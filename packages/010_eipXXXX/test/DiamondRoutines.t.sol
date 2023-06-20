// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {DiamondConstants, console} from "./utils/DiamondConstants.t.sol";
import {DiamondLoupeFacet} from "../src/facets/diamond/DiamondLoupeFacet.sol";
import {DiamondCutFacet} from "../src/facets/diamond/DiamondCutFacet.sol";
import {OwnershipFacet} from "../src/facets/diamond/OwnershipFacet.sol";
import {IDiamond} from "../src/interfaces/IDiamond.sol";
import {DiamondArgs, Diamond} from "../src/Diamond.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

contract DiamondRoutines is DiamondConstants {
  function _deployDiamondEssentials()
    private
    returns (IDiamond.FacetCut memory, IDiamond.FacetCut memory)
  {
    loupe = new DiamondLoupeFacet();
    cut = new DiamondCutFacet();
    return (
      IDiamond.FacetCut(address(loupe), IDiamond.FacetCutAction.Add, loupeSelectors),
      IDiamond.FacetCut(address(cut), IDiamond.FacetCutAction.Add, cutSelectors)
    );
  }

  function _deploySimpleDiamond() internal {
    IDiamond.FacetCut[] memory coreFacets = new IDiamond.FacetCut[](3);
    (coreFacets[0], coreFacets[1]) = _deployDiamondEssentials();
    ownership = new OwnershipFacet();
    coreFacets[2] =
      IDiamond.FacetCut(address(ownership), IDiamond.FacetCutAction.Add, ownershipSelectors);
    init = address(0);
    DiamondArgs memory args = DiamondArgs(address(this), init, "0x00");
    diamond = address(new Diamond(coreFacets, args));
  }

  // function _deployDiamondYieldVault(
  //   address asset,
  //   address chief,
  //   string memory name,
  //   string memory symbol
  // )
  //   internal
  // {
  //   IDiamond.FacetCut[] memory yieldVaultFacets = new IDiamond.FacetCut[](3);
  //   (yieldVaultFacets[0], yieldVaultFacets[1]) = _deployDiamondEssentials();
  // }
}
