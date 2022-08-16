// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {Const} from "./Const.s.sol";
import {OnchainPermitHelper} from "../src/OnchainPermitHelper.sol";
import {SimpleRouterForTesting} from "../src/SimpleRouterForTesting.sol";
import {BorrowingVault} from "../src/BorrowingVault.sol";
import {IERC20Mintable} from "@xfuji/interfaces/IERC20Mintable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RunXPermitTest is Const, Test {
    /**
  This test bridges collateral to a destination chain
  and then opens a debt position using permit
  authorization.
  Run commands on console this way:
  > source .env
  > forge script script/RunXPermitTest.s.sol:RunXPermitTest --rpc-url $ORIGIN_URL --private-key <PKEY>
  ENSURE:
  - wallet has sufficient funds.
  - there is a .env file with: 
      - export PRIVATE_KEY_TEST=<PKEY>
      - export ORIGIN_DOM=<1234>
      - export ORIGIN_URL=<RPC_URL>
      - export DEST_DOM=<5678>
      - export DEST_URL=<RPC_URL>
  */

    /// Testing params
    uint256 public amountToDeposit = 2 * 1e18;
    uint256 public amountToBorrow = 200 * 1e6;

    // state variables
    IERC20Mintable public weth;
    OnchainPermitHelper public helper;
    BorrowingVault public bvault;
    SimpleRouterForTesting public srouter;

    uint256 public originDomain;
    string public origin_rpc_URL;
    uint256 public originFork;

    uint256 public destDomain;
    string public destination_rpc_URL;
    uint256 public destFork;

    function run() public {
        _assignVariables();
        _createForks();

        // vm.selectFork(destFork);
        // (bytes32 digest_, uint256 deadline) = _getDigest();
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(vm.envUint('PRIVATE_KEY_TEST'), digest_);
        // _consoleLogInfo(deadline, v, r, s);

        uint256 deadline = 1660766334;
        uint8 v = 28;
        bytes32 r = 0x19486fae7c62e37aebe78f5f7eed5299a0d3b100ac24ded0810873cce734b0fb;
        bytes32 s = 0x417cfa80f777801b5744e454e7d4a0e14da7dbfe7e2138c355c730e54afdc548;

        vm.startBroadcast();
        _getAndApproveWETH();
        srouter.bridgeDepositAndBorrow(
            destDomain,
            address(bvault),
            address(weth),
            amountToDeposit,
            amountToBorrow,
            deadline,
            v,
            r,
            s
        );
        vm.stopBroadcast();
    }

    function _createForks() internal {
        originFork = vm.createFork(origin_rpc_URL);
        destFork = vm.createFork(destination_rpc_URL);
    }

    function _assignVariables() internal {
        helper = OnchainPermitHelper(SIGHELPER);
        bvault = BorrowingVault(BVAULT);
        srouter = SimpleRouterForTesting(SROUTER);
        originDomain = vm.envUint("ORIGIN_DOM");
        origin_rpc_URL = vm.envString("ORIGIN_URL");
        destDomain = vm.envUint("DEST_DOM");
        destination_rpc_URL = vm.envString("DEST_URL");
        _setWETHAddr();
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
        console.log("srouter.bridgeDepositAndBorrow(");
        console.log("destDomain", destDomain);
        console.log("address(weth)", address(weth));
        console.log("address(bvault)", address(bvault));
        console.log("amountToDeposit", amountToDeposit);
        console.log("amountToBorrow", amountToBorrow);
        console.log("deadline", deadline);
        console.log("v", v);
        console.log("r");
        console.logBytes32(r);
        console.log("s");
        console.logBytes32(s);
    }
}
