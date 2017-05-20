#!/bin/bash
#
#
#
echo "[INFO] Please connect your devices now..."
read
echo "[TESTCASE] emtpty config"
./ascent -c "test/empty_config" "dryrun"
echo "[TESTCASE] invalid config"
./ascent -c "test/invalid_config" "dryrun"
echo "[TESTCASE] valid config"
./ascent -c "test/valid_config" "dryrun"
echo "[INFO] Please disconnect one device now"
read
echo "[TESTCASE] not both devices are connected"
./ascent -c "test/valid_config" "dryrun"
