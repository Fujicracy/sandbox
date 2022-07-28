#!/usr/bin/env bash

RPC_URL=$RPC_GOERLI

ASSET=0x2e3A2fb8473316A02b8A297B982498E661E1f6f5
DEBT_ASSET=0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43
ORACLE=0xD7E3AE6f48A1D442069b32a5Aa6e315B111B992C
WETH=0x2e3A2fb8473316A02b8A297B982498E661E1f6f5
TEST_TOKEN=0x26FE8a8f86511d678d031a022E48FfF41c6a3e3b
CONNEXT_HANDLER=0x6c9a905Ab3f4495E2b47f5cA131ab71281E0546e

AAVE_V3=$(forge create AaveV3Goerli --rpc-url $RPC_URL \
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

echo "AAVE_V3_G=$AAVE_V3"
echo "ROUTER_G=$ROUTER"
echo "VAULT_G=$VAULT"
