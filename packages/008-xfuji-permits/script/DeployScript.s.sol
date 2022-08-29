// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import {Const} from "./Const.s.sol";

import {ILendingProvider} from "@xfuji/interfaces/ILendingProvider.sol";
import {BorrowingVault} from "../src/BorrowingVault.sol";
import {IVault} from "../src/IVault.sol";
import {IConnext} from "../src/connext/IConnext.sol";
import {IWETH} from "@xfuji/interfaces/IWETH.sol";
import {SimpleRouterForTesting} from "../src/SimpleRouterForTesting.sol";
import {OnchainPermitHelper} from "../src/OnchainPermitHelper.sol";
import {AaveV3Goerli} from "../src/providers/goerli/AaveV3Goerli.sol";
import {AaveV3OptiG} from "../src/providers/optimistic_goerli/AaveV3OptiG.sol";
import {AaveV3Rinkeby} from "../src/providers/rinkeby/AaveV3Rinkeby.sol";
import {AaveV3Mumbai} from "../src/providers/mumbai/AaveV3Mumbai.sol";
import {MockEACAggregatorProxy} from "../src/mocks/MockEACAggregatorProxy.sol";
import {FujiOracle} from "../src/FujiOracle.sol";

contract DeployScript is Const, Script {
    enum Chains {
        goerli,
        optimisticG,
        rinkeby,
        mumbai
    }

    Chains public deployChain = Chains.goerli;

    address public weth;
    address public usdc;
    address public connextHandler;
    address public testToken;

    MockEACAggregatorProxy public mockWethPriceFeed;
    MockEACAggregatorProxy public mockUsdcPriceFeed;
    FujiOracle public fujioracle;

    address[] public priceFeeds = new address[](2);
    address[] public assets = new address[](2);

    ILendingProvider public aaveV3;
    BorrowingVault public bvault;
    SimpleRouterForTesting public srouter;
    OnchainPermitHelper public helper;

    function run() public {
        vm.startBroadcast();
        _setAddresses(deployChain);
        fujioracle = new FujiOracle(
            assets,
            priceFeeds
        );
        bvault = new BorrowingVault(weth, usdc, address(fujioracle));
        _setUpBorrowingVault(bvault);
        srouter = new SimpleRouterForTesting(
            IConnext(connextHandler),
            IWETH(weth)
        );
        _setUpSimpleRouterForTesting(srouter, address(bvault));
        helper = new OnchainPermitHelper();
        vm.stopBroadcast();

        console.log("weth-priceFeed", address(mockWethPriceFeed));
        console.log("usdc-priceFeed", address(mockUsdcPriceFeed));
        console.log("fujioracle", address(fujioracle));
        console.log("aaveV3", address(aaveV3));
        console.log("bvault", address(bvault));
        console.log("srouter", address(srouter));
        console.log("helper", address(helper));
    }

    function _setAddresses(Chains _deployChain) internal {
        if (_deployChain == Chains.rinkeby) {
            weth = WETH_RINKEBY;
            usdc = USDC_RINKEBY;
            connextHandler = CONNEXT_HANDLER_RINKEBY;
            testToken = TEST_TOKEN_RINKEBY;
            AaveV3Rinkeby arinkeby = new AaveV3Rinkeby();
            aaveV3 = ILendingProvider(address(arinkeby));
        } else if (_deployChain == Chains.goerli) {
            weth = WETH_GOERLI;
            usdc = USDC_GOERLI;
            connextHandler = CONNEXT_HANDLER_GOERLI;
            testToken = TEST_TOKEN_GOERLI;
            AaveV3Goerli agoerli = new AaveV3Goerli();
            aaveV3 = ILendingProvider(address(agoerli));
        } else if (_deployChain == Chains.mumbai) {
            weth = WETH_MUMBAI;
            usdc = USDC_MUMBAI;
            connextHandler = CONNEXT_HANDLER_MUMBAI;
            testToken = TEST_TOKEN_MUMBAI;
            AaveV3Mumbai amumbai = new AaveV3Mumbai();
            aaveV3 = ILendingProvider(address(amumbai));
        } else if (_deployChain == Chains.optimisticG) {
            weth = WETH_OPTIMISM_G;
            usdc = USDC_OPTIMISM_G;
            connextHandler = CONNEXT_HANDLER_OPTIMISM_G;
            testToken = TEST_TOKEN_OPTIMISM_G;
            AaveV3OptiG aoptiG = new AaveV3OptiG();
            aaveV3 = ILendingProvider(address(aoptiG));
        }
        mockWethPriceFeed = new MockEACAggregatorProxy();
        mockUsdcPriceFeed = new MockEACAggregatorProxy();
        assets[0] = weth;
        assets[1] = usdc;
        priceFeeds[0] = address(mockWethPriceFeed);
        priceFeeds[1] = address(mockUsdcPriceFeed);
    }

    function _setUpBorrowingVault(BorrowingVault bVault_) internal {
        ILendingProvider[] memory providers = new ILendingProvider[](1);
        providers[0] = aaveV3;
        bVault_.setProviders(providers);
        bVault_.setActiveProvider(aaveV3);
    }

    function _setUpSimpleRouterForTesting(
        SimpleRouterForTesting srouter_,
        address bvault_
    ) internal {
        for (uint256 i = 0; i < DOMAIN_IDS.length; ) {
            srouter_.setRouter(DOMAIN_IDS[i], address(srouter_));
            unchecked {
                ++i;
            }
        }
        srouter_.registerVault(IVault(bvault_));
        srouter_.setTestnetToken(testToken);
    }
}
