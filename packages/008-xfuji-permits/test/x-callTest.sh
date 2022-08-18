#!/usr/bin/env bash
source .env
forge script --rpc-url $DEST_URL script/GetSignedDigest.s.sol:GetSignedDigest
source script/temp/sig_values.txt
forge script --rpc-url $ORIGIN_URL --private-key $PRIVATE_KEY --broadcast --slow script/SendXCall.s.sol:SendXCall