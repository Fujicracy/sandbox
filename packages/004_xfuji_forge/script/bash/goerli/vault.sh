#!/usr/bin/env bash

. ./script/bash/goerli/common.sh

AAVE_V3=$(cat ./deployments/goerli/AaveV3Goerli)

deploy_contract Vault --constructor-args $ASSET $DEBT_ASSET $ORACLE

VAULT=$(cat ./deployments/goerli/Vault)

cast_tx $VAULT "setActiveProvider(address)" $AAVE_V3
