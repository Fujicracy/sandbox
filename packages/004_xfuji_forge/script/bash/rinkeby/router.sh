#!/usr/bin/env bash

. ./script/bash/rinkeby/common.sh

deploy_contract Router --constructor-args $WETH $CONNEXT_HANDLER

ROUTER=$(cat ./deployments/rinkeby/Router)

cast_tx $ROUTER "setTestnetToken(address)" $TEST_TOKEN
