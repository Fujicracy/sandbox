#!/usr/bin/env bash

. ./script/bash/rinkeby/common.sh

AAVE_V3=$(cat ./deployments/rinkeby/AaveV3Rinkeby)

deploy_contract Vault --constructor-args $ASSET $DEBT_ASSET $ORACLE

VAULT=$(cat ./deployments/rinkeby/Vault)

cast_tx $VAULT "setActiveProvider(address)" $AAVE_V3
