// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {TestParams} from "./TestParams.s.sol";
import {Const} from "./Const.s.sol";
import {OnchainPermitHelper} from "../src/OnchainPermitHelper.sol";
import {SimpleRouterForTesting} from "../src/SimpleRouterForTesting.sol";
import {BorrowingVault} from "../src/BorrowingVault.sol";
import {IERC20Mintable} from "@xfuji/interfaces/IERC20Mintable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Temporary files
import {TempR} from "./temp/TempR.s.sol";
import {TempS} from "./temp/TempS.s.sol";

contract SendXCall is TestParams, Const, Test {
    /**
    This test bridges collateral to a destination chain
    and then opens a debt position using permit
    authorization.
    1.- First ENSURE the following:
    - a test wallet has sufficient funds.
    - there is a .env file with: 
        - export PRIVATE_KEY=<PKEY>
        - export ORIGIN_DOM=<1234>
        - export ORIGIN_URL=<RPC_URL>
        - export DEST_DOM=<5678>
        - export DEST_URL=<RPC_URL>

    2.- Run commands on console this way:
    > source .env
    > forge script --rpc-url $DEST_URL script/GetSignedDigest.s.sol:GetSignedDigest
    > forge script --rpc-url $ORIGIN_URL --private-key $PRIVATE_KEY --broadcast --slow script/SendXCall.s.sol:SendXCall

  */

    // state variables
    IERC20Mintable public weth;
    OnchainPermitHelper public helper;
    BorrowingVault public bvault;
    SimpleRouterForTesting public srouter;

    uint256 public destDomain;
    uint256 public originDomain;

    function run() public {
        _assignVariables();

        uint256 deadline = _st2uint256(vm.readFile("script/temp/deadline.txt"));
        uint8 v = uint8(_st2uint256(vm.readFile("script/temp/V.txt")));
        bytes32 r = _stringToBytes32(vm.readFile("script/temp/R.txt"));
        bytes32 s = _stringToBytes32(vm.readFile("script/temp/S.txt"));

        string memory hexString = vm.readFile("script/temp/R.txt");

        string memory hstr = "aa";
        uint stringInBytes32 = _st2uint256(hstr)-39*2;
        uint num = 0xaa;
        bool isTrue = stringInBytes32 == num;
        console.log(isTrue);
        console.log(hstr);
        console.log(stringInBytes32);

        console.log("r from read:", hexString);
        console.logBytes(bytes(hexString));

        _consoleLogInfo(deadline, v, r, s);

        // vm.startBroadcast();
        // _getAndApproveWETH();
        // srouter.bridgeDepositAndBorrow(
        //     destDomain,
        //     address(bvault),
        //     address(weth),
        //     amountToDeposit,
        //     amountToBorrow,
        //     deadline,
        //     v,
        //     r,
        //     s
        // );
        // _consoleLogInfo(deadline, v, r, s);
        // vm.stopBroadcast();
    }

    function _assignVariables() internal {
        bvault = BorrowingVault(BVAULT);
        srouter = SimpleRouterForTesting(SROUTER);
        destDomain = vm.envUint("DEST_DOM");
        originDomain = vm.envUint("ORIGIN_DOM");
        _setWETHAddr();
    }

    function _getAndApproveWETH() internal {
        weth.mint(msg.sender, amountToDeposit);
        IERC20(address(weth)).approve(SROUTER, amountToDeposit);
    }

    function _setWETHAddr() internal {
        if (originDomain == DOMAIN_ID_RINKEBY) {
            weth = IERC20Mintable(WETH_RINKEBY);
        } else if (originDomain == DOMAIN_ID_GOERLI) {
            weth = IERC20Mintable(WETH_GOERLI);
        } else if (originDomain == DOMAIN_ID_MUMBAI) {
            weth = IERC20Mintable(WETH_MUMBAI);
        }
    }

    function _consoleLogInfo(
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        console.log("deadline", deadline);
        console.log("v", v);
        console.log("r");
        console.logBytes32(r);
        console.log("s");
        console.logBytes32(s);
    }

    function _st2uint256(string memory numString)
        internal
        pure
        returns (uint256)
    {
        uint256 val = 0;
        bytes memory stringBytes = bytes(numString);
        for (uint256 i = 0; i < stringBytes.length; i++) {
            uint256 exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
            uint256 jval = uval - uint256(0x30);

            val += (uint256(jval) * (10**(exp - 1)));
        }
        return val;
    }

    function _stringToBytes32(string memory source)
        internal
        pure
        returns (bytes32 result)
    {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
}
