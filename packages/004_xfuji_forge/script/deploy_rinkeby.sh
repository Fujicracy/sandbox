#!/usr/bin/env bash

RPC_URL=$RPC_RINKEBY

ASSET=0xd74047010D77c5901df5b0f9ca518aED56C85e8D
DEBT_ASSET=0xb18d016cDD2d9439A19f15633005A6b2cd6Aa774
ORACLE=0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C
WETH=0xd74047010D77c5901df5b0f9ca518aED56C85e8D
TEST_TOKEN=0x3FFc03F05D1869f493c7dbf913E636C6280e0ff9
CONNEXT_HANDLER=0x4cAA6358a3d9d1906B5DABDE60A626AAfD80186F

AAVE_V3=$(forge create AaveV3Rinkeby --rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--etherscan-api-key $ETHERSCAN_KEY --verify | grep 'Deployed to:' | awk '{print $NF}')

ROUTER=$(forge create Router --constructor-args $WETH $CONNEXT_HANDLER --rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--etherscan-api-key $ETHERSCAN_KEY --verify | grep 'Deployed to:' | awk '{print $NF}')

VAULT=$(forge create Vault --constructor-args $ASSET $DEBT_ASSET $ORACLE $ROUTER --rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--etherscan-api-key $ETHERSCAN_KEY --verify | grep 'Deployed to:' | awk '{print $NF}')

cast send $VAULT "setActiveProvider(address)" $AAVE_V3 --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send $ROUTER "registerVault(address)" $VAULT --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send $ROUTER "setTestnetToken(address)" $TEST_TOKEN --rpc-url $RPC_URL --private-key $PRIVATE_KEY

echo "AAVE_V3_R=$AAVE_V3"
echo "ROUTER_R=$ROUTER"
echo "VAULT_R=$VAULT"
