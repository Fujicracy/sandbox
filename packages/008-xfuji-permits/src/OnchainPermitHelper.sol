// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.15;

import {BorrowingVault} from "./BorrowingVault.sol";

contract OnchainPermitHelper {
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

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    uint256 public delay;

    constructor() {
      delay = 1 days;
    }

    function setDelay(uint256 newDelay) external {
      // TODO admin restricted function
      delay= newDelay;
    }

    // computes the hash of a permit-asset
    function getStructHashAsset(
        BorrowingVault bvault_,
        address owner,
        address spender,
        uint256 value
    ) public view returns (bytes32 structHash_, uint256 deadline_) {
        deadline_ = block.timestamp + delay;
        Permit memory _permit = Permit({
            owner: owner,
            spender: spender,
            value: value,
            nonce: bvault_.nonces(owner),
            deadline: deadline_
        });
        structHash_ = keccak256(
            abi.encode(
                _PERMIT_ASSET_TYPEHASH,
                _permit.owner,
                _permit.spender,
                _permit.value,
                _permit.nonce,
                _permit.deadline
            )
        );
    }

    // computes the hash of a permit-debt
    function getStructHashDebt(
        BorrowingVault bvault_,
        address owner,
        address spender,
        uint256 value
    ) public view returns (bytes32 structHash_, uint256 deadline_) {
        deadline_ = block.timestamp + delay;
        Permit memory _permit = Permit({
            owner: owner,
            spender: spender,
            value: value,
            nonce: bvault_.nonces(owner),
            deadline: deadline_
        });
        structHash_ = keccak256(
            abi.encode(
                _PERMIT_DEBT_TYPEHASH,
                _permit.owner,
                _permit.spender,
                _permit.value,
                _permit.nonce,
                _permit.deadline
            )
        );
    }

    // computes the digest
    function gethashTypedDataV4Digest(
        BorrowingVault bvault_,
        bytes32 structHash_
    ) external view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    _getDomainSeperator(bvault_),
                    structHash_
                )
            );
    }

    function _getDomainSeperator(BorrowingVault bvault_)
        internal
        view
        returns (bytes32)
    {
        return bvault_.DOMAIN_SEPARATOR();
    }
}
