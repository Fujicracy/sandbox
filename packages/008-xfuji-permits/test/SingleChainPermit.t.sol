// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// Testing imports
import "forge-std/Test.sol";
import {HelperPermissions} from "./HelperPermissions.t.sol";

/// XFuji imports
import {ILendingProvider} from "@xfuji/interfaces/ILendingProvider.sol";
import {FujiOracle} from "@xfuji/FujiOracle.sol";
import {BorrowingVault} from "../src/BorrowingVault.sol";

contract SingleChainPermitTests is Test, HelperPermissions {
    using stdStorage for StdStorage;

    Chains public testingChain = Chains.goerli;

    FujiOracle public oracle;
    BorrowingVault public bvault;
    
    address public userWithFunds = vm.addr(1);
    address public operator = vm.addr(2);

    uint public depositAmount = 10 * 1e18;
    uint public withdrawDelegated = 3 * 1e18;

    function setUp() public {
        _setAddresses(testingChain);
        _deployFujiOracle();
        _startMockPriceFeedCalls();
        bvault = new BorrowingVault(
            weth,
            usdc,
            address(oracle)
        );
        ILendingProvider[] memory providers = new ILendingProvider[](1);
        providers[0] = aaveV3;
        bvault.setProviders(providers);
        bvault.setActiveProvider(aaveV3);
    }

    function testDeposit() public {
        uint256 amount = depositAmount;
        _writeDepositBalance(userWithFunds, address(bvault), amount);
        assertEq(bvault.balanceOf(userWithFunds), depositAmount);
    }

    function _writeDepositBalance(address who, address vault, uint256 amount) internal {
        stdstore
            .target(vault)
            .sig(bvault.balanceOf.selector)
            .with_key(who)
            .checked_write(amount);
    }

    function _deployFujiOracle() internal {
        address[] memory addr =  new address[](2);
        address[] memory priceFeeds = new address[](2);
        addr[0] = weth;
        addr[1] = usdc;
        priceFeeds[0] = wethPriceFeed;
        priceFeeds[1] = usdcPriceFeed;
        oracle = new FujiOracle(
            addr,
            priceFeeds
        );
    }

    function _deployAaveV3Provider() internal {

    }
}
