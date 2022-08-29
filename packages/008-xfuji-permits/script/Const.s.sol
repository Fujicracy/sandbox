// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

contract Const {
    //  Latest deployment addresses August-16-2022:

    address public constant BVAULT = 0x84cae60A4a1A058101E8Cab325E3745102811350;
    address public constant SROUTER =
        0x69A2c6d4dc6A5De2459b6E7D0e5deeD3da2C9cAf;
    address public constant SIGHELPER =
        0x09Cf11E589A10B097D00Af8767284983f01D918C;

    // External constants and addresses:

    address public constant FUJI_ORACLE =
        0x459B490F86e6B7C86086511D6a378f8C4b313D17;
    address public constant AAVE_V3_PROVIDER =
        0xc5d5a86E9f752e241eAc96a0595E4Cd6adc05F5a;

    uint32 public constant DOMAIN_ID_RINKEBY = 1111;
    address public constant WETH_RINKEBY =
        0xd74047010D77c5901df5b0f9ca518aED56C85e8D;
    address public constant USDC_RINKEBY =
        0xb18d016cDD2d9439A19f15633005A6b2cd6Aa774;
    address public constant CONNEXT_HANDLER_RINKEBY =
        0x4cAA6358a3d9d1906B5DABDE60A626AAfD80186F;
    address public constant TEST_TOKEN_RINKEBY =
        0x3FFc03F05D1869f493c7dbf913E636C6280e0ff9;

    uint32 public constant DOMAIN_ID_GOERLI = 1735353714;
    address public constant WETH_GOERLI =
        0x2e3A2fb8473316A02b8A297B982498E661E1f6f5;
    address public constant USDC_GOERLI =
        0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43;
    address public constant CONNEXT_HANDLER_GOERLI =
        0xB4C1340434920d70aD774309C75f9a4B679d801e;
    address public constant TOKEN_REGISTRY_GOERLI =
        0x3f95CEF37566D0B101b8F9349586757c5D1F2504;
    address public constant TEST_TOKEN_GOERLI =
        0x7ea6eA49B0b0Ae9c5db7907d139D9Cd3439862a1;

    uint32 public constant DOMAIN_ID_OPTIMISM_G = 1735356532;
    address public constant WETH_OPTIMISM_G =
        0x09bADef78f92F20fd5f7a402dbb1d25d4901aAb2;
    address public constant USDC_OPTIMISM_G =
        0xf1485Aa729DF94083ab61B2C65EeA99894Aabdb3;
    address public constant CONNEXT_HANDLER_OPTIMISM_G =
        0xe37f1f55eab648dA87047A03CB03DeE3d3fe7eC7;
    address public constant TOKEN_REGISTRY_OPTIMISM_G =
        0x67fE7B3a2f14c6AC690329D433578eEFE59954C8;
    address public constant TEST_TOKEN_OPTIMISM_G =
        0x68Db1c8d85C09d546097C65ec7DCBFF4D6497CbF;

    uint32 public constant DOMAIN_ID_MUMBAI = 9991;
    address public constant WETH_MUMBAI =
        0xd575d4047f8c667E064a4ad433D04E25187F40BB;
    address public constant USDC_MUMBAI =
        0x9aa7fEc87CA69695Dd1f879567CcF49F3ba417E2;
    address public constant CONNEXT_HANDLER_MUMBAI =
        0x765cbd312ad84A791908000DF58d879e4eaf768b;
    address public constant TEST_TOKEN_MUMBAI =
        0x21c5a4dAeAf9625c781Aa996E9229eA95EE4Ff77;

    uint32[] public DOMAIN_IDS = [
        DOMAIN_ID_RINKEBY,
        DOMAIN_ID_GOERLI,
        DOMAIN_ID_MUMBAI
    ];
}
