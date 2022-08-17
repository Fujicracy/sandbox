// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {TestParams} from "./TestParams.s.sol";
import {Const} from "./Const.s.sol";
import {OnchainPermitHelper} from "../src/OnchainPermitHelper.sol";
import {BorrowingVault} from "../src/BorrowingVault.sol";

contract GetSignedDigest is Const, TestParams, Test {
    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _PERMIT_ASSET_TYPEHASH =
        keccak256(
            "PermitAssets(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _PERMIT_DEBT_TYPEHASH =
        keccak256(
            "PermitDebt(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    OnchainPermitHelper public helper;
    BorrowingVault public bvault;
    address public owner;

    string public destination_rpc_URL;

    function run() public {
        _assignVariables();
        (bytes32 digest, uint256 deadline) = _getDigest();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _readPKey(),
            digest
        );
        _consoleLogInfo(digest, deadline, v, r, s);
        _saveTempFiles(digest, deadline, v, r, s);
    }

    function _assignVariables() internal {
        helper = OnchainPermitHelper(SIGHELPER);
        bvault = BorrowingVault(BVAULT);
        owner = vm.addr(_readPKey());
    }

    function _readPKey() internal returns (uint256 key) {
        bytes memory readBytes = vm.envBytes("PRIVATE_KEY");
        key = _bytesToUint(readBytes);
    }

    function _bytesToUint(bytes memory b)
        internal
        pure
        returns (uint256 number)
    {
        for (uint256 i = 0; i < b.length; i++) {
            number =
                number +
                uint256(uint8(b[i])) *
                (2**(8 * (b.length - (i + 1))));
        }
    }

    function _getDigest()
        internal
        view
        returns (bytes32 digest_, uint256 deadline_)
    {
        (bytes32 _structHash, uint256 deadline) = helper.getStructHashDebt(
            bvault,
            owner,
            SROUTER,
            amountToBorrow
        );
        deadline_ = deadline;
        console.log("who is signing:", owner);
        assert(
            _verifyStructHashDebt(
                bvault,
                owner,
                SROUTER,
                amountToBorrow,
                deadline,
                _structHash
            )
        );
        digest_ = helper.gethashTypedDataV4Digest(bvault, _structHash);
    }

    function _consoleLogInfo(
        bytes32 digest,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        console.log("digest");
        console.logBytes32(digest);
        console.log("deadline", deadline);
        console.log("v", v);
        console.log("r");
        console.logBytes32(r);
        console.log("s");
        console.logBytes32(s);
    }

    function _saveTempFiles(
        bytes32 _digest,
        uint256 _deadline,
        uint256 _v,
        bytes32 _r,
        bytes32 _s
    ) internal {
        _saveDigest(_digest);
        _saveDeadline(_deadline);
        _saveEnvSigValues(_v, _r, _s);
    }

    function _saveDigest(bytes32 _digest) internal {
        vm.writeFile("script/temp/Digest.txt", vm.toString(_digest));
    }

    function _saveDeadline(uint256 _deadline) internal {
        vm.writeFile("script/temp/deadline.txt", vm.toString(_deadline));
    }

    function _saveEnvSigValues(
        uint256 _v,
        bytes32 _r,
        bytes32 _s
    ) internal {
        vm.writeFile(
            "script/temp/sig_values.txt",
            string(
                abi.encodePacked(
                    " export V_VALUE=",
                    vm.toString(_v),
                    " export R_VALUE=",
                    vm.toString(_r),
                    " export S_VALUE=",
                    vm.toString(_s)
                )
            )
        );
    }

    // function _saveV(uint256 _v) internal {
    //     vm.writeFile("script/temp/V.txt", vm.toString(_v));
    // }

    // function _saveR(bytes32 _r) internal {
    //     vm.writeFile(
    //         "script/temp/temp_r.variable",
    //         string(
    //             abi.encodePacked(
    //                 '// SPDX-License-Identifier: UNLICENSED'
    //                 'pragma solidity 0.8.15; ',
    //                 'contract TempR {  ',
    //                 'bytes32 public constant R_VALUE =',vm.toString(_r),';',
    //                 '}'
    //             )
    //         )
    //     );
    // }

    // function _saveS(bytes32 _s) internal {
    //     vm.writeFile("script/temp/S.txt", vm.toString(_s));
    // }

    function _verifyStructHashAsset(
        BorrowingVault bvault_,
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        bytes32 readStructHash_
    ) internal view returns (bool isCorrect_) {
        Permit memory _permit = Permit({
            owner: owner_,
            spender: spender_,
            value: value_,
            nonce: bvault_.nonces(owner_),
            deadline: deadline_
        });
        bytes32 structHash_ = keccak256(
            abi.encode(
                _PERMIT_ASSET_TYPEHASH,
                _permit.owner,
                _permit.spender,
                _permit.value,
                _permit.nonce,
                _permit.deadline
            )
        );
        isCorrect_ = structHash_ == readStructHash_;
    }

    function _verifyStructHashDebt(
        BorrowingVault bvault_,
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        bytes32 readStructHash_
    ) internal view returns (bool isCorrect_) {
        Permit memory _permit = Permit({
            owner: owner_,
            spender: spender_,
            value: value_,
            nonce: bvault_.nonces(owner_),
            deadline: deadline_
        });
        bytes32 structHash_ = keccak256(
            abi.encode(
                _PERMIT_DEBT_TYPEHASH,
                _permit.owner,
                _permit.spender,
                _permit.value,
                _permit.nonce,
                _permit.deadline
            )
        );
        isCorrect_ = structHash_ == readStructHash_;
    }
}
