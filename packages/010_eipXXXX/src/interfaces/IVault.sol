// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {IERC20Metadata} from "./IERC20Metadata.sol";
import {IERC4626} from "./IERC4626.sol";
import {IERC4627} from "./IERC4627.sol";

interface IVault is IERC4626, IERC4627, IERC20Metadata {}
