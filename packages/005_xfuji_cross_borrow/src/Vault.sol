
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract Vault is ERC4626 {
  /*IRouter public router;*/

  address private immutable _debtAsset;

  uint16 public maxLtv;
  uint16 public liqRatio;

  constructor(
    address _asset,
    address debtAsset_,
    address _router,
    uint16 _maxLtv,
    uint16 _liqRatio
  ) 
    ERC4626(IERC20Metadata(_asset))
    ERC20(
      // ex: Fuji-X Dai Stablecoin Vault Shares
      string(abi.encodePacked("Fuji-X ", IERC20Metadata(asset_).name(), "-", IERC20Metadata(debtAsset_).name(), " Vault Shares")),
      // ex: fxDAI
      string(abi.encodePacked("fx", IERC20Metadata(asset_).symbol(), "-", IERC20Metadata(debtAsset_).symbol()))
    )
  {
    /*router = IRouter(_router);*/
    _debtAsset = debtAsset_
    maxLtv = _maxLtv;
    liqRatio = _liqRatio;
  }
}
