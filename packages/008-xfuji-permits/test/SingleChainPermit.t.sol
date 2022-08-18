// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// Testing imports
import "forge-std/Test.sol";
import {HelperPermissions} from "./HelperPermissions.t.sol";
import {SigUtilsHelper} from "./HelperPermissions.t.sol";

/// XFuji imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingProvider} from "@xfuji/interfaces/ILendingProvider.sol";
import {FujiOracle} from "@xfuji/FujiOracle.sol";
import {BorrowingVault} from "../src/BorrowingVault.sol";

/// ALL TESTS ARE ASSUMED WITH WETH COLLATERAL, USDC DEBT
contract SingleChainPermitTests is Test, HelperPermissions {
    using stdStorage for StdStorage;

    Chains public testingChain = Chains.goerli;
    SigUtilsHelper public sigUtils;

    FujiOracle public oracle;
    BorrowingVault public bvault;

    uint256 internal ownerPrivateKey = 1;
    uint256 internal operatorPrivateKey = 2;
    address public owner = vm.addr(ownerPrivateKey);
    address public operator = vm.addr(operatorPrivateKey);

    uint256 public depositAmount = 10 * 1e18;
    uint256 public withdrawDelegated = 3 * 1e18;
    uint256 public borrowDelegated = 200 * 1e6;

    function setUp() public {
        _setAddresses(testingChain);
        _deployFujiOracle();
        bvault = new BorrowingVault(weth, usdc, address(oracle));
        _setUpLendingProvider();
        _setUpSignatureHelper();
    }

    function testFailOperatorTriesWithdraw() internal {
        _doDeposit();
        vm.prank(operator);
        bvault.withdraw(withdrawDelegated, operator, owner);
        assertEq(IERC20(weth).balanceOf(operator), 0);
    }

    function testWithdrawWithPermit() internal {
        _doDeposit();
        SigUtilsHelper.Permit memory permit = SigUtilsHelper.Permit({
            owner: owner,
            spender: operator,
            value: withdrawDelegated,
            nonce: bvault.nonces(owner),
            deadline: block.timestamp + 1 days
        });
        bytes32 digest = sigUtils.gethashTypedDataV4Digest(
            bvault.DOMAIN_SEPARATOR(), // This domain should be obtained from the chain on which state will change.
            sigUtils.getStructHashAsset(permit)
        );
        console.log("test-asset-digest");
        console.logBytes32(digest);
        // This message signing is supposed to be off-chain
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bvault.permitAssets(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
        assertEq(bvault.assetAllowance(owner, operator), withdrawDelegated);
        vm.prank(operator);
        bvault.withdraw(withdrawDelegated, operator, owner);
        assertEq(IERC20(weth).balanceOf(operator), withdrawDelegated);
    }

    function testFailOperatorTriesBorrow() public {
        _doDeposit();
        vm.prank(operator);
        bvault.borrow(borrowDelegated, operator, owner);
        assertEq(IERC20(usdc).balanceOf(operator), 0);
    }

    function testBorrowWithPermit() public {
        _doDeposit();
        SigUtilsHelper.Permit memory permit = SigUtilsHelper.Permit({
            owner: owner,
            spender: operator,
            value: borrowDelegated,
            nonce: bvault.nonces(owner),
            deadline: block.timestamp + 1 days
        });
        bytes32 digest = sigUtils.gethashTypedDataV4Digest(
            bvault.DOMAIN_SEPARATOR(), // This domain should be obtained from the chain on which state will change.
            sigUtils.getStructHashDebt(permit)
        );
        console.log("test-borrow-digest");
        console.logBytes32(digest);
        // This message signing is supposed to be off-chain
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bvault.permitDebt(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
        assertEq(bvault.debtAllowance(owner, operator), borrowDelegated);
        _startMockPriceFeedCalls();
        vm.prank(operator);
        bvault.borrow(borrowDelegated, operator, owner);
        assertEq(IERC20(usdc).balanceOf(operator), borrowDelegated);
    }

    function _doDeposit() internal {
        _writeWethBalance(owner, depositAmount);
        vm.startPrank(owner);
        IERC20(weth).approve(address(bvault), depositAmount);
        bvault.deposit(depositAmount, owner);
        vm.stopPrank();
        assertEq(IERC20(weth).balanceOf(owner), 0);
        assertEq(bvault.balanceOf(owner), depositAmount);
    }

    function _testOwnerWithdraw() internal {
        _writeWethBalance(owner, depositAmount);
        assertEq(IERC20(weth).balanceOf(owner), depositAmount);
        vm.startPrank(owner);
        IERC20(weth).approve(address(bvault), depositAmount);
        bvault.deposit(depositAmount, owner);
        assertEq(IERC20(weth).balanceOf(owner), 0);
        bvault.withdraw(withdrawDelegated, owner, owner);
        assertEq(IERC20(weth).balanceOf(owner), withdrawDelegated);
        vm.stopPrank();
    }

    function _writeDepositBalance(
        address who,
        address vault,
        uint256 amount
    ) internal {
        stdstore
            .target(vault)
            .sig(bvault.balanceOf.selector)
            .with_key(who)
            .checked_write(amount);
    }

    function _writeWethBalance(address who, uint256 amount) internal {
        stdstore
            .target(weth)
            .sig(IERC20(weth).balanceOf.selector)
            .with_key(who)
            .checked_write(amount);
        assertEq(IERC20(weth).balanceOf(who), amount);
    }

    function _deployFujiOracle() internal {
        address[] memory addr = new address[](2);
        address[] memory priceFeeds = new address[](2);
        addr[0] = weth;
        addr[1] = usdc;
        priceFeeds[0] = wethPriceFeed;
        priceFeeds[1] = usdcPriceFeed;
        oracle = new FujiOracle(addr, priceFeeds);
    }

    function _setUpLendingProvider() internal {
        ILendingProvider[] memory providers = new ILendingProvider[](1);
        providers[0] = aaveV3;
        bvault.setProviders(providers);
        bvault.setActiveProvider(aaveV3);
    }

    function _setUpSignatureHelper() internal {
        sigUtils = new SigUtilsHelper();
    }
}
