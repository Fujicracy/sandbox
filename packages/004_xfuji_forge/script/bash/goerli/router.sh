#!/usr/bin/env bash

. ./script/bash/goerli/common.sh

deploy_contract Router --constructor-args $WETH $CONNEXT_HANDLER

ROUTER=$(cat ./deployments/goerli/Router)

cast_tx $ROUTER "setTestnetToken(address)" $TEST_TOKEN
