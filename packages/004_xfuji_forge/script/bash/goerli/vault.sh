#!/usr/bin/env bash

. ./script/bash/goerli/common.sh

AAVE_V3=$(cat ./deployments/goerli/AaveV3Goerli)

ROUTER=$(cat ./deployments/goerli/XRouter)

deploy_contract Vault --constructor-args $ASSET $DEBT_ASSET $ORACLE $ROUTER

VAULT=$(cat ./deployments/goerli/Vault)

cast_tx $VAULT "setActiveProvider(address)" $AAVE_V3

cast_tx $ROUTER "registerVault(address)" $VAULT
