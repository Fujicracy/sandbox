// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

import "hardhat/console.sol";

contract PermitProcessor {
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    address public mockTokenAddress;

    constructor(address mockTokenAddress_) {
        mockTokenAddress = mockTokenAddress_;
    }

    function transferFromWithPermit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(mockTokenAddress).permit(
            owner,
            spender,
            value,
            deadline,
            v,
            r,
            s
        );
        IERC20(mockTokenAddress).transferFrom(owner, address(this), value);
        IERC20(mockTokenAddress).transfer(msg.sender, value);
    }

    function permitMessage(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) external view returns (bytes32 digest) {
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                IERC20Permit(mockTokenAddress).nonces(owner),
                deadline
            )
        );
        digest = keccak256(abi.encodePacked("\x19\x01", IERC20Permit(mockTokenAddress).DOMAIN_SEPARATOR(), structHash));
    }
}
