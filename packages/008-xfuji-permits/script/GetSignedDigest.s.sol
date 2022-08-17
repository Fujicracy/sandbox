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
        // (bytes32 digest_, uint256 deadline) = _getDigest();
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(
        //     _readPKey(),
        //     digest_
        // );
        bytes32 digest_ = 0x0fa9b765f35e9f176d5dd53b817185e8f693a3a6407a4ff5c55ed9b3402b4f80;
        uint256 deadline = 1660842300;
        uint8 v = 27;
        bytes32 s = 0x0fa9b765f35e9f176d5dd53b817185e8f693a3a6407a4ff5c55ed9b3402b4f81;
        bytes32 r = 0x0fa9b765f35e9f176d5dd53b817185e8f693a3a6407a4ff5c55ed9b3402b4f82;
        _consoleLogInfo(digest_, deadline, v, r, s);
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

    function _bytesToUint(bytes memory b) internal pure returns (uint256 number){
        for(uint i=0;i<b.length;i++){
            number = number + uint(uint8(b[i]))*(2**(8*(b.length-(i+1))));
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
    ) internal {
        console.log("digest");
        console.logBytes32(digest);
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

    function _saveDigest(uint256 _digest) internal {
        vm.writeFile("script/temp/Digest.txt", vm.toString(_digest));
    }

    function _saveDeadline(uint256 _deadline) internal {
        vm.writeFile("script/temp/deadline.txt", vm.toString(_deadline));
    }

    function _saveV(uint256 _v) internal {
        vm.writeFile("script/temp/V.txt", vm.toString(_v));
    }

    function _saveR(bytes32 _r) internal {
        vm.writeFile(
            "script/temp/TempR.s.sol", 
            string(
                abi.encode(
                    '// SPDX-License-Identifier: UNLICENSED'
                    'pragma solidity 0.8.15; ',
                    'contract TempR {  ',
                    'bytes32 public constant R_VALUE =',vm.toString(_r),';',
                    '}'
                )
            )
        );
    }

    function _saveS(bytes32 _s) internal {
        vm.writeFile("script/temp/S.txt", vm.toString(_s));
    }

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
