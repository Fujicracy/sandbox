#!/usr/bin/env bash

USER_ADDR=$(cast wallet address --private-key $PRIVATE_KEY)

# GOERLI depoyment and configs

g_RPC_URL=$RPC_GOERLI
g_DOMAIN=3331

g_ASSET=0x2e3A2fb8473316A02b8A297B982498E661E1f6f5
g_DEBT_ASSET=0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43
g_ORACLE=0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C
g_WETH=0x2e3A2fb8473316A02b8A297B982498E661E1f6f5
g_TEST_TOKEN=0x26FE8a8f86511d678d031a022E48FfF41c6a3e3b
g_CONNEXT_HANDLER=0x6c9a905Ab3f4495E2b47f5cA131ab71281E0546e

g_AAVE_V3=$(forge create AaveV3Goerli --rpc-url $g_RPC_URL \
--private-key $PRIVATE_KEY \
--etherscan-api-key $ETHERSCAN_KEY --verify | grep 'Deployed to:' | awk '{print $NF}')

g_ROUTER=$(forge create Router --constructor-args $g_WETH $g_CONNEXT_HANDLER --rpc-url $g_RPC_URL \
--private-key $PRIVATE_KEY \
--etherscan-api-key $ETHERSCAN_KEY --verify | grep 'Deployed to:' | awk '{print $NF}')

g_VAULT=$(forge create Vault --constructor-args $g_ASSET $g_DEBT_ASSET $g_ORACLE $g_ROUTER --rpc-url $g_RPC_URL \
--private-key $PRIVATE_KEY \
--etherscan-api-key $ETHERSCAN_KEY --verify | grep 'Deployed to:' | awk '{print $NF}')

cast send $g_VAULT "setActiveProvider(address)" $g_AAVE_V3 --rpc-url $g_RPC_URL --private-key $PRIVATE_KEY
cast send $g_ROUTER "registerVault(address)" $g_VAULT --rpc-url $g_RPC_URL --private-key $PRIVATE_KEY
cast send $g_ROUTER "setTestnetToken(address)" $g_TEST_TOKEN --rpc-url $g_RPC_URL --private-key $PRIVATE_KEY

# RINKEBY depoyment and configs

r_RPC_URL=$RPC_RINKEBY
r_DOMAIN=1111

r_ASSET=0xd74047010D77c5901df5b0f9ca518aED56C85e8D
r_DEBT_ASSET=0xb18d016cDD2d9439A19f15633005A6b2cd6Aa774
r_ORACLE=0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C
r_WETH=0xd74047010D77c5901df5b0f9ca518aED56C85e8D
r_TEST_TOKEN=0x3FFc03F05D1869f493c7dbf913E636C6280e0ff9
r_CONNEXT_HANDLER=0x4cAA6358a3d9d1906B5DABDE60A626AAfD80186F

r_AAVE_V3=$(forge create AaveV3Rinkeby --rpc-url $r_RPC_URL \
--private-key $PRIVATE_KEY \
--etherscan-api-key $ETHERSCAN_KEY --verify | grep 'Deployed to:' | awk '{print $NF}')

r_ROUTER=$(forge create Router --constructor-args $r_WETH $r_CONNEXT_HANDLER --rpc-url $r_RPC_URL \
--private-key $PRIVATE_KEY \
--etherscan-api-key $ETHERSCAN_KEY --verify | grep 'Deployed to:' | awk '{print $NF}')

r_VAULT=$(forge create Vault --constructor-args $r_ASSET $r_DEBT_ASSET $r_ORACLE $r_ROUTER --rpc-url $r_RPC_URL \
--private-key $PRIVATE_KEY \
--etherscan-api-key $ETHERSCAN_KEY --verify | grep 'Deployed to:' | awk '{print $NF}')

cast send $r_VAULT "setActiveProvider(address)" $r_AAVE_V3 --rpc-url $r_RPC_URL --private-key $PRIVATE_KEY
cast send $r_ROUTER "registerVault(address)" $r_VAULT --rpc-url $r_RPC_URL --private-key $PRIVATE_KEY
cast send $r_ROUTER "setTestnetToken(address)" $r_TEST_TOKEN --rpc-url $r_RPC_URL --private-key $PRIVATE_KEY

# Set cross router addresses

cast send $g_ROUTER "setRouter(uint256,address)" $r_DOMAIN $r_ROUTER --rpc-url $g_RPC_URL --private-key $PRIVATE_KEY
cast send $r_ROUTER "setRouter(uint256,address)" $g_DOMAIN $g_ROUTER --rpc-url $r_RPC_URL --private-key $PRIVATE_KEY

# Ineract with the bridge from RINKEBY

AMOUNT=$(cast --to-wei 10)

# mint some WETH
cast send $r_WETH "mint(address,uint256)" $USER_ADDR $AMOUNT --rpc-url $r_RPC_URL --private-key $PRIVATE_KEY
# approve router for weth
cast send $r_WETH "approve(address,uint256)" $r_ROUTER $AMOUNT --rpc-url $r_RPC_URL --private-key $PRIVATE_KEY
# call bridgeDepositToVault
cast send $r_ROUTER "bridgeDepositToVault(address,uint256,uint256,address)" $r_WETH $AMOUNT $g_DOMAIN $g_VAULT --rpc-url $r_RPC_URL --private-key $PRIVATE_KEY

# Displays

echo "g_AAVE_V3=$g_AAVE_V3"
echo "g_ROUTER=$g_ROUTER"
echo "g_VAULT=$g_VAULT"

echo "r_AAVE_V3=$r_AAVE_V3"
echo "r_ROUTER=$r_ROUTER"
echo "r_VAULT=$r_VAULT"
