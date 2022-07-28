// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "./interfaces/connext/IConnext.sol";
import "./interfaces/connext/IExecutor.sol";
import "./interfaces/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Testnet only: mapper of equivalent assets on destination chain.
import "./mocks/TestnetMapper.sol";

// Testnet only
interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}

contract Router {
    struct VaultParams {
        address asset;
        address debtAsset;
    }

    mapping(uint256 => address) public routerByDomain;

    IConnext public connext; // TODO SECURITY make immutable
    address public promiseRouter; // TODO SECURITY make immutable
    IExecutor public executor; // The address of the Connext Executor contract

    mapping(IVault => VaultParams) public registeredVaults;

    // Testnet only: dummy test token for required connext argument.
    address public connextTestToken;
    // Testnet only: dummy wallet that receives token dump during testing.
    address public DUMMY_WALLET = 0x3b51Bc41C9Eda453aa50b6Bc43D48e0795Ce52f2;
    // Testnet only: tesnet mapper for aave asset addresses at destination chain.
    ITestnetMapper public tesnetMapper;

    // A modifier for permissioning the callback.
    // Note: This is an important security consideration. Only the PromiseRouter (the
    //       Connext contract that executes the callback function) should be able to
    //       call the callback function.
    modifier onlyPromiseRouter() {
        require(msg.sender == address(promiseRouter), "Expected PromiseRouter");
        _;
    }

    // A modifier for permissioned function calls.
    // Note: This is an important security consideration. If your target
    //       contract function is meant to be permissioned, it must check
    //       that the originating call is from the correct domain and contract.
    //       Also, check that the msg.sender is the Connext Executor address.
    modifier onlyConnextExecutor(uint32 originDomain) {
        require(
            IExecutor(msg.sender).originSender() ==
                routerByDomain[originDomain] &&
                IExecutor(msg.sender).origin() == originDomain &&
                msg.sender == address(executor),
            "Expected origin contract on origin domain called by Executor"
        );
        _;
    }

    constructor(
        IConnext connext_,
        address promiseRouter_,
        address connextTestToken_,
        IVault vault_,
        address tesnetMapper_
    ) {
        connext = connext_;
        promiseRouter = promiseRouter_;
        executor = connext.executor();

        registerVault(vault_);

        connextTestToken = connextTestToken_;
        tesnetMapper = ITestnetMapper(tesnetMapper_);
    }

    function depositBorrow(
        IVault vault,
        uint256 assets,
        uint256 debt,
        address owner
    ) public {
        _depositBorrow(vault, assets, debt, msg.sender, msg.sender, owner);
    }

    function depositBorrowAndBridgeTestnet(
        IVault vault,
        uint256 assets,
        uint256 debt,
        address owner,
        uint32 destDomain
    ) external {
        // Testnet only: send testnet token to DUMMY_WALLET, mint collateral assets
        // Required: since Connext doesnt support bridging of Aave asset types.
        _beforeDepositBorrowTestnetHook(vault, assets);

        _depositBorrowTestnet(vault, assets, debt, address(this), owner); // Testnet only:

        // Testnet only: send borrowed tokens to DUMMY_WALLET, and mint debt as testnet token
        // Required: since Connext doesnt support bridging of Aave asset types.
        _afterDepositBorrowTestnetHook(vault, debt);

        // Testnet only: disburseTestnet() needs to be called on dest chain since connext doesnt support bridging of Aave asset types.
        address mapped = tesnetMapper.getMapping(
            registeredVaults[vault].debtAsset,
            destDomain
        );

        uint32 originDomain = uint32(connext.domain());

        bytes memory callData = abi.encodeWithSelector(
            Router.disburseTestnet.selector,
            debt,
            owner,
            mapped,
            originDomain
        );

        IConnext.CallParams memory callParams = IConnext.CallParams({
            to: routerByDomain[destDomain],
            callData: callData,
            originDomain: originDomain,
            destinationDomain: destDomain,
            agent: routerByDomain[destDomain], // address allowed to transaction on destination side in addition to relayers
            recovery: routerByDomain[destDomain], // fallback address to send funds to if execution fails on destination side
            forceSlow: true, // option to force Nomad slow path (~30 mins) instead of paying 0.05% fee
            receiveLocal: false, // option to receive the local Nomad-flavored asset instead of the adopted asset
            callback: address(0), // this contract implements the callback
            callbackFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
            relayerFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
            slippageTol: 9995 // tolerate .05% slippage
        });

        IConnext.XCallArgs memory xcallArgs = IConnext.XCallArgs({
            params: callParams,
            transactingAssetId: connextTestToken,
            amount: debt
        });

        connext.xcall(xcallArgs);
    }

    function _depositBorrow(
        IVault vault,
        uint256 assets,
        uint256 debt,
        address caller,
        address receiver,
        address owner
    ) internal {
        // TODO SECURITY permit operation for borrowing on-behalf the owner!!!!
        address asset = registeredVaults[vault].asset;
        require(asset != address(0), "Not registered!");
        SafeERC20.safeTransferFrom(
            IERC20(asset),
            caller,
            address(this),
            assets
        );
        vault.deposit(assets, owner);
        vault.borrow(debt, receiver, owner);
    }

    function _depositBorrowTestnet(
        IVault vault,
        uint256 assets,
        uint256 debt,
        address receiver,
        address owner
    ) internal {
        // TODO SECURITY permit operation for borrowing on-behalf the owner!!!!
        address asset = registeredVaults[vault].asset;
        require(asset != address(0), "Not registered!");
        vault.deposit(assets, owner);
        vault.borrow(debt, receiver, owner);
    }

    // Testnet only: send testnet token to DUMMY_WALLET, mint collateral assets
    // Required: since Connext doesn't support bridging of Aave asset types.
    function _beforeDepositBorrowTestnetHook(IVault vault, uint256 assets)
        internal
    {
        SafeERC20.safeTransferFrom(
            IERC20(connextTestToken),
            msg.sender,
            DUMMY_WALLET,
            assets
        );
        address asset = registeredVaults[vault].asset;
        IERC20Mintable(asset).mint(address(this), assets); // Minting weth collateral accepted in AaveV3.
    }

    // Testnet only: send borrowed tokens to DUMMY_WALLET, and mint debt as testnet token
    // Required: since Connext doesnt support bridging of Aave asset types.
    function _afterDepositBorrowTestnetHook(IVault vault, uint256 debt)
        internal
    {
        address debtAsset = registeredVaults[vault].debtAsset;
        SafeERC20.safeTransfer(IERC20(debtAsset), DUMMY_WALLET, debt);
        IERC20Mintable(connextTestToken).mint(address(this), debt);
        SafeERC20.safeApprove(IERC20(connextTestToken), address(connext), debt); // Removing Connext Test Token
    }

    // Testnet only: mint debt asset on destination chain since connext doesnt support bridging of Aave specific asset types.
    function disburseTestnet(
        uint256 amount,
        address owner,
        address mapped,
        uint32 originDomain
    ) external onlyConnextExecutor(originDomain) {
        SafeERC20.safeTransferFrom(
            IERC20(connextTestToken),
            msg.sender,
            DUMMY_WALLET,
            amount
        );
        IERC20Mintable(mapped).mint(owner, amount);
    }

    ///////////////////////
    /// Admin functions ///
    ///////////////////////

    // Testnet only: needed as argument to make xCalls at ConnextHandler
    function setConnextTestToken(address addr_) external {
        connextTestToken = addr_;
    }

    // Testnet only: needed since connext doesnt support bridging of Aave specific asset types.
    function setTestnetMapper(address addr_) external {
        tesnetMapper = ITestnetMapper(addr_);
    }

    function setRouter(uint32 domain, address router) external {
        // TODO SECURITY restrict this function
        routerByDomain[domain] = router;
        // TODO emit an event
    }

    function setConnextHandler(address addr_) external {
        // TODO SECURITY remove this setter function.
        connext = IConnext(addr_);
    }

    function setPromiseRouter(address addr_) external {
        // TODO SECURITY remove this setter function.
        promiseRouter = addr_;
    }

    function registerVault(IVault vault) public {
        // TODO SECURITY restrict this function
        VaultParams memory params;
        address asset = vault.asset();
        params.asset = asset;
        SafeERC20.safeApprove(IERC20(asset), address(vault), type(uint256).max);
        try vault.debtAsset() {
            address debtAsset = vault.debtAsset();
            params.debtAsset = debtAsset;
            SafeERC20.safeApprove(
                IERC20(debtAsset),
                address(vault),
                type(uint256).max
            );
        } catch {
            params.debtAsset = address(0);
        }
        registeredVaults[vault] = params;
        // TODO emit an event
    }
}
