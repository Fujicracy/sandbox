// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

contract Flenda {

  struct Factor {
    uint64 num;
    uint64 denum;
  }

  struct PosManager {
    address collatAsset;
    address debtAsset;
    address[] lendingProviders;
    address activeProvider;
    uint256 collatShares;
    uint256 debtShares;
    uint256 collatBalance;
    uint256 debtBalance;
    uint128 managerId;
    uint128 chainId;
    Factor maxLtv;
    Factor liqRatio;
  }

  struct Pos {
    uint256 collatShares;
    uint256 debtShares;
    uint128 managerId;
    Factor liqBonusFee;
  }

  struct UserData {
    // DAcct[] deposits;
    Pos[] positions;
  }

  // user address => UserData
  mapping(address => UserData) private _userData;
  // asset address => managerId => DAcctManager
  // mapping(address => uint128 => DAcctManager) private _dacctManagers;
  // collateral address => debt address => managerID => PosManager
  mapping(address => mapping(address => mapping(uint128 => PosManager))) private _posManagers;

}
