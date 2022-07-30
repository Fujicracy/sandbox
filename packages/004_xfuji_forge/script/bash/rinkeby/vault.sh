#!/usr/bin/env bash

. ./script/bash/rinkeby/common.sh

AAVE_V3=$(cat ./deployments/rinkeby/AaveV3Rinkeby)

ROUTER=$(cat ./deployments/rinkeby/Router)

deploy_contract Vault --constructor-args $ASSET $DEBT_ASSET $ORACLE $ROUTER

VAULT=$(cat ./deployments/rinkeby/Vault)

cast_tx $VAULT "setActiveProvider(address)" $AAVE_V3

cast_tx $ROUTER "registerVault(address)" $VAULT
