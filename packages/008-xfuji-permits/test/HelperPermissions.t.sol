// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// Test imports
import "forge-std/Test.sol";

/// Xfuji imports
import {IAggregatorV3} from "@xfuji/interfaces/chainlink/IAggregatorV3.sol";
import {ILendingProvider} from "@xfuji/interfaces/ILendingProvider.sol";
import {AaveV3Goerli} from "@xfuji/providers/goerli/AaveV3Goerli.sol";
import {AaveV3Rinkeby} from "@xfuji/providers/rinkeby/AaveV3Rinkeby.sol";
import {AaveV3Mumbai} from "../src/providers/mumbai/AaveV3Mumbai.sol";

contract HelperPermissions is Test {

    enum Chains {
      goerli,
      rinkeby,
      mumbai
    }

    address public constant WETH_RINKEBY =
        0xd74047010D77c5901df5b0f9ca518aED56C85e8D;
    address public constant WETH_GOERLI =
        0x2e3A2fb8473316A02b8A297B982498E661E1f6f5;
    address public constant WETH_MUMBAI =
        0xd575d4047f8c667E064a4ad433D04E25187F40BB;

    address public constant USDC_RINKEBY =
        0xb18d016cDD2d9439A19f15633005A6b2cd6Aa774;
    address public constant USDC_GOERLI =
        0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43;
    address public constant USDC_MUMBAI =
        0x9aa7fEc87CA69695Dd1f879567CcF49F3ba417E2;

    address public weth;
    address public usdc;
    address public wethPriceFeed = vm.addr(100);
    address public usdcPriceFeed = vm.addr(101);

    ILendingProvider public aaveV3;

    function _setAddresses(Chains _testchain) internal {
        if (_testchain == Chains.goerli) {
            vm.createSelectFork("goerli");
            weth = WETH_GOERLI;
            usdc = USDC_GOERLI;
            AaveV3Goerli agoerli = new AaveV3Goerli();
            aaveV3 = ILendingProvider(address(agoerli));
        } else if (_testchain == Chains.rinkeby) {
            vm.createSelectFork("rinkeby");
            weth = WETH_RINKEBY;
            usdc = USDC_RINKEBY;
            AaveV3Rinkeby arinkeby = new AaveV3Rinkeby();
            aaveV3 = ILendingProvider(address(arinkeby));
        } else if (_testchain == Chains.mumbai) {
            vm.createSelectFork("mumbai");
            weth =  WETH_MUMBAI;
            usdc = USDC_MUMBAI;
            AaveV3Mumbai amumbai = new AaveV3Mumbai();
            aaveV3 = ILendingProvider(address(amumbai));
        }
    }

    function _startMockPriceFeedCalls() internal {
        uint80 roundId = 1;
        uint256 startedAt = 1;
        uint256 updatedAt = 1;
        uint80 answeredInRound = 1;
        int256 answerWeth = 1500 * 1e8;
        vm.mockCall(
            wethPriceFeed,
            abi.encodeWithSelector(IAggregatorV3.latestRoundData.selector),
            abi.encode(
                roundId,
                answerWeth,
                startedAt,
                updatedAt,
                answeredInRound
            )
        );
        int256 answerUsdc = 1 * 1e8;
        vm.mockCall(
            wethPriceFeed,
            abi.encodeWithSelector(IAggregatorV3.latestRoundData.selector),
            abi.encode(
                roundId,
                answerUsdc,
                startedAt,
                updatedAt,
                answeredInRound
            )
        );
    }
}
