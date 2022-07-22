// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "./interfaces/connext/IConnext.sol";
import "./interfaces/IVault.sol";

contract LendingRouterInbound {

  IConnext public immutable connext;
  address public immutable promiseRouter;

  constructor(IConnext _connext, address _promiseRouter) {
    connext = _connext;
    promiseRouter = _promiseRouter;
  }

  function depositAndBorrow() external {
  }



}