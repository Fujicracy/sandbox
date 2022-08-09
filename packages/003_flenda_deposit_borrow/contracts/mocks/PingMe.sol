// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "../interfaces/connext/IConnext.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IPingMe {

  event IWasPinged(address indexed caller, uint256 totalPings, string message);

  function justPing(string memory msg_) external;

  function pingAndPingBack(string memory msg_, address pingReceiver_, uint32 destDomain) external;
}

contract PingMe is IPingMe {
    IConnext public connext;
    address public promiseRouter;
    address public testToken;

    // Testnet only: ping to check Connext bridge working.
    uint256 public totalPings;

    constructor(IConnext connext_, address promiseRouter_, address testToken_) {
        connext = connext_;
        promiseRouter = promiseRouter_;
        testToken = testToken_;
    }

    // Testnet only: ping to check Connext bridge working.
    function justPing(string memory msg_) public override {
        totalPings++;
        emit IWasPinged(msg.sender, totalPings, msg_);
    }

    function pingAndPingBack(string memory msg_, address pingReceiver_, uint32 destDomain) public override {
        justPing(msg_);

        string memory newMsg = "I am pinging back";

        bytes memory callData = abi.encodeWithSelector(
            IPingMe.justPing.selector,
            newMsg
        );

        uint32 originDomain = uint32(connext.domain());

        IConnext.CallParams memory callParams = IConnext.CallParams({
            to: pingReceiver_,
            callData: callData,
            originDomain: originDomain,
            destinationDomain: destDomain,
            agent: pingReceiver_, // address allowed to transaction on destination side in addition to relayers
            recovery: pingReceiver_, // fallback address to send funds to if execution fails on destination side
            forceSlow: true, // option to force Nomad slow path (~30 mins) instead of paying 0.05% fee
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

    function pushTokensOut(address token_) public {
      IERC20 token = IERC20(token_);
      uint bal = token.balanceOf(address(this));
      token.transfer(msg.sender, bal);
    }

    function setConnextHandler(address addr_) external {
        connext = IConnext(addr_);
    }

    function setPromiseRouter(address addr_) external {
        promiseRouter = addr_;
    }

    function setTestToken(address addr_) external {
        testToken = addr_;
    }
}
