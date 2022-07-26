// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Contract that stores and returns addresses mappings
 * Required for getting contract addresses for some providers and flashloan providers
 */
interface ITestnetMapper {
    function getMapping(address originAsset, uint32 destDomain)
        external
        view
        returns (address);
}

contract TesnetMapper is Ownable {
    // Origin chain asset => destination domain => equivalent chain asset
    mapping(address => mapping(uint32 => address)) private _addrMapping;

    function getMapping(address originAsset, uint32 destDomain)
        public
        view
        returns (address)
    {
        return _addrMapping[originAsset][destDomain];
    }

    function setMappings(
        uint32 destDomain,
        address[] memory originAddr_,
        address[] memory destAddr_
    ) public onlyOwner {
        uint256 olenght = originAddr_.length;
        require(olenght == destAddr_.length, "Invalid inputs!");
        for (uint256 i = 0; i < olenght; ) {
            _addrMapping[originAddr_[i]][destDomain] = destAddr_[i];
            unchecked {
                ++i;
            }
        }
    }
}
