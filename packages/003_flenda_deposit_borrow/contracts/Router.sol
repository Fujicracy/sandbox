// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.9;

import "./interfaces/connext/IConnext.sol";
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

    mapping(uint32 => address) public routerByDomain;

    IConnext public immutable connext;
    address public immutable promiseRouter;

    mapping(IVault => VaultParams) public registeredVaults;

    // Testnet only: dummy test token for required connext argument.
    address public connextTestToken;
    // Testnet only: dummy wallet that receives token dump during testing.
    address public DUMMY_WALLET = 0x3b51Bc41C9Eda453aa50b6Bc43D48e0795Ce52f2;
    // Testnet only: tesnet mapper for aave asset addresses at destination chain.
    address public tesnetMapper;

    // A modifier for permissioning the callback.
    // Note: This is an important security consideration. Only the PromiseRouter (the
    //       Connext contract that executes the callback function) should be able to
    //       call the callback function.
    modifier onlyPromiseRouter() {
        require(msg.sender == address(promiseRouter), "Expected PromiseRouter");
        _;
    }

    constructor(IConnext _connext, address _promiseRouter) {
        connext = _connext;
        promiseRouter = _promiseRouter;
    }

    function depositBorrow(
        IVault vault,
        uint256 assets,
        uint256 debt,
        address owner
    ) public {
        _depositBorrow(vault, assets, debt, msg.sender, msg.sender, owner);
    }

    function depositBorrowAndBridge(
        IVault vault,
        uint256 assets,
        uint256 debt,
        address owner,
        uint32 destDomain
    ) external {
        _depositBorrow(vault, assets, debt, msg.sender, address(this), owner);

        // Testnet only: send borrowed assets to DUMMY_WALLET since connext doesnt support bridging of Aave asset types.
        _beforeTestnetHook(vault, debt);

        // Testnet only: disburseTestnet() needs to be called on dest chain since connext doesnt support bridging of Aave asset types.
        address mapped = ITestnetMapper(tesnetMapper).getMapping(registeredVaults[vault].debtAsset, destDomain);
        bytes memory callData = abi.encodeWithSelector(
            Router.disburseTestnet.selector,
            debt,
            owner,
            mapped
        );

        uint32 originDomain = uint32(connext.domain());

        IConnext.CallParams memory callParams = IConnext.CallParams({
            to: routerByDomain[destDomain],
            callData: callData,
            originDomain: originDomain,
            destinationDomain: destDomain,
            agent: msg.sender, // address allowed to transaction on destination side in addition to relayers
            recovery: msg.sender, // fallback address to send funds to if execution fails on destination side
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
            amount: 0
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

    // Testnet only: send borrowed assets to DUMMY_WALLET since connext doesnt support bridging of Aave specific asset types.
    function _beforeTestnetHook(IVault vault, uint256 debt) internal {
        address debtAsset = registeredVaults[vault].debtAsset;
        SafeERC20.safeTransfer(IERC20(debtAsset), DUMMY_WALLET, debt);
    }

    // Testnet only: mint asset on destination chain since connext doesnt support bridging of Aave specific asset types.
    function disburseTestnet(
        uint256 amount,
        address owner,
        address mapped
    ) external onlyPromiseRouter {
        IERC20Mintable(mapped).mint(owner, amount);
    }

    ///////////////////////
    /// Admin functions ///
    ///////////////////////

    // Testnet only
    function setConnextTestToken(address addr_) external {
        connextTestToken = addr_;
    }

    function registerRouter(uint32 domain, address router) external {
        // TODO SECURITY restrict this function
        routerByDomain[domain] = router;
        // TODO emit an event
    }

    function registerVault(IVault vault) external {
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
        // TODO emit an event
    }
}
