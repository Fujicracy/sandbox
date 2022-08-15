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
            weth = WETH_MUMBAI;
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
            usdcPriceFeed,
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

contract SigUtilsHelper {

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

    // computes the hash of a permit-asset
    function getStructHashAsset(Permit memory _permit)
        public
        pure
        returns (bytes32)
    {
        return
            keccak256(
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
    function getStructHashDebt(Permit memory _permit)
        public
        pure
        returns (bytes32)
    {
        return
            keccak256(
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
    function gethashTypedDataV4Digest(bytes32 domainSeperator_, bytes32 structHash_) external pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeperator_, structHash_));
    }
}
