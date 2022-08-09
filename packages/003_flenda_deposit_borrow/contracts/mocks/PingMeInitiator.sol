// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "../interfaces/connext/IConnext.sol";
import "./PingMe.sol";

contract PingMeInitiator {
    address constant PINGME_ADDR = 0xd41D09D455E9BD2cFa7FD42c235b933EF7604dD9;

    IConnext public connext;
    address public promiseRouter;
    address public testToken;

    constructor(
        IConnext connext_,
        address promiseRouter_,
        address testToken_
    ) {
        connext = connext_;
        promiseRouter = promiseRouter_;
        testToken = testToken_;
    }

    function initiatePing(
        string memory msg_,
        uint32 destDomain
    ) public {
        bytes memory callData = abi.encodeWithSelector(
            IPingMe.justPing.selector,
            msg_
        );

        uint32 originDomain = uint32(connext.domain());

        IConnext.CallParams memory callParams = IConnext.CallParams({
            to: PINGME_ADDR,
            callData: callData,
            originDomain: originDomain,
            destinationDomain: destDomain,
            agent: PINGME_ADDR, // address allowed to transaction on destination side in addition to relayers
            recovery: PINGME_ADDR, // fallback address to send funds to if execution fails on destination side
            forceSlow: false, // option to force Nomad slow path (~30 mins) instead of paying 0.05% fee
            receiveLocal: false, // option to receive the local Nomad-flavored asset instead of the adopted asset
            callback: address(0), // this contract implements the callback
            callbackFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
            relayerFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
            slippageTol: 9995 // tolerate .05% slippage
        });

        IConnext.XCallArgs memory xcallArgs = IConnext.XCallArgs({
            params: callParams,
            transactingAssetId: testToken,
            amount: 0
        });

        connext.xcall(xcallArgs);
    }
}
