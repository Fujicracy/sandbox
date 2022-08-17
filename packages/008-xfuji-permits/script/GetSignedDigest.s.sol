// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {TestParams} from "./TestParams.s.sol";
import {Const} from "./Const.s.sol";
import {OnchainPermitHelper} from "../src/OnchainPermitHelper.sol";
import {BorrowingVault} from "../src/BorrowingVault.sol";

contract GetSignedDigest is Const, TestParams, Test {
    OnchainPermitHelper public helper;
    BorrowingVault public bvault;

    uint256 public destFork;
    string public destination_rpc_URL;

    function run() public {
        _assignVariables();
        (bytes32 digest_, uint256 deadline) = _getDigest();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            vm.envUint("PRIVATE_KEY"),
            digest_
        );
        _consoleLogInfo(deadline, v, r, s);
    }

    function _assignVariables() internal {
        helper = OnchainPermitHelper(SIGHELPER);
        bvault = BorrowingVault(BVAULT);
        destination_rpc_URL = vm.envString("DEST_URL");
        destFork = vm.createFork(destination_rpc_URL);
    }

    function _getDigest()
        internal
        returns (bytes32 digest_, uint256 deadline_)
    {
        vm.selectFork(destFork);
        (bytes32 _structHash, uint256 deadline) = helper.getStructHashDebt(
            bvault,
            msg.sender,
            SROUTER,
            amountToBorrow
        );
        deadline_ = deadline;
        digest_ = helper.gethashTypedDataV4Digest(bvault, _structHash);
    }

    function _consoleLogInfo(
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        console.log("deadline", deadline);
        console.log("v", v);
        console.log("r");
        console.logBytes32(r);
        console.log("s");
        console.logBytes32(s);
        _saveDeadline(deadline);
        _saveV(v);
        _saveR(r);
        _saveS(s);
    }

    function _saveDeadline(uint _deadline) internal {
        vm.writeFile("script/temp/deadline.txt", vm.toString(_deadline));
    }
    function _saveV(uint _v) internal {
        vm.writeFile("script/temp/V.txt", vm.toString(_v));
    }
    function _saveR(bytes32 _r) internal {
        vm.writeFile("script/temp/R.txt", vm.toString(_r));
    }
    function _saveS(bytes32 _s) internal {
        vm.writeFile("script/temp/S.txt", vm.toString(_s));
    }
}
