// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {IERC20, IERC20Metadata} from "../../src/interfaces/IERC20Metadata.sol";
import {IERC4626} from "../../src/interfaces/IERC4626.sol";

contract VaultConstants {
  bytes4[] public erc20Selectors;
  bytes4[] public erc20MetadataSelectors;
  bytes4[] public erc4626Selectors;

  constructor() {
    bytes4[] memory erc20Selectors_ = new bytes4[](6);
    erc20Selectors_[0] = bytes4(IERC20.totalSupply.selector);
    erc20Selectors_[1] = bytes4(IERC20.balanceOf.selector);
    erc20Selectors_[2] = bytes4(IERC20.transfer.selector);
    erc20Selectors_[3] = bytes4(IERC20.allowance.selector);
    erc20Selectors_[4] = bytes4(IERC20.approve.selector);
    erc20Selectors_[5] = bytes4(IERC20.transferFrom.selector);
    erc20Selectors = erc20Selectors_;

    bytes4[] memory erc20MetadataSelectors_ = new bytes4[](9);
    for (uint256 i; i < erc20Selectors_.length;) {
      erc20MetadataSelectors_[i] = erc20Selectors_[i];
      unchecked {
        ++i;
      }
    }
    erc20MetadataSelectors_[6] = bytes4(IERC20Metadata.name.selector);
    erc20MetadataSelectors_[7] = bytes4(IERC20Metadata.symbol.selector);
    erc20MetadataSelectors_[8] = bytes4(IERC20Metadata.decimals.selector);
    erc20MetadataSelectors = erc20MetadataSelectors_;

    bytes4[] memory erc4626Selectors_ = new bytes4[](25);
    for (uint256 i; i < erc20MetadataSelectors_.length;) {
      erc4626Selectors_[i] = erc20MetadataSelectors_[i];
      unchecked {
        ++i;
      }
    }
    erc4626Selectors_[9] = bytes4(IERC4626.asset.selector);
    erc4626Selectors_[10] = bytes4(IERC4626.totalAssets.selector);
    erc4626Selectors_[11] = bytes4(IERC4626.convertToShares.selector);
    erc4626Selectors_[12] = bytes4(IERC4626.convertToAssets.selector);
    erc4626Selectors_[13] = bytes4(IERC4626.maxDeposit.selector);
    erc4626Selectors_[14] = bytes4(IERC4626.previewDeposit.selector);
    erc4626Selectors_[15] = bytes4(IERC4626.deposit.selector);
    erc4626Selectors_[16] = bytes4(IERC4626.maxMint.selector);
    erc4626Selectors_[17] = bytes4(IERC4626.previewMint.selector);
    erc4626Selectors_[18] = bytes4(IERC4626.mint.selector);
    erc4626Selectors_[19] = bytes4(IERC4626.maxWithdraw.selector);
    erc4626Selectors_[20] = bytes4(IERC4626.previewWithdraw.selector);
    erc4626Selectors_[21] = bytes4(IERC4626.withdraw.selector);
    erc4626Selectors_[22] = bytes4(IERC4626.maxRedeem.selector);
    erc4626Selectors_[23] = bytes4(IERC4626.previewRedeem.selector);
    erc4626Selectors_[24] = bytes4(IERC4626.redeem.selector);
    erc4626Selectors = erc4626Selectors_;
  }
}
