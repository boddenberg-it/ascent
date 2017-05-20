#!/bin/bash
#
# Simple script to verify config parsing. The color of [TESTCASE] lines
# indicate expected test result.

# colors
NC="\033[0m"
R="\033[0;31m"
G="\033[0;32m"
B="\033[0;35m"

echo
echo -e "${R}[TESTCASE] EMPTY CONFIG ${NC}"
./ascent -c "configs_for_tests/empty_config" "dryrun"

echo -e "${R}[TESTCASE] INVALID CONFIG ${NC}"
./ascent -c "configs_for_tests/invalid_config" "dryrun"

echo -e "${B}[INFO] Please connect ONE device now...${NC}"
read
echo -e "${R}[TESTCASE] ONLY ONE DEVICE IS CONNECTED ${NC}"
./ascent -c "configs_for_tests/valid_config" "dryrun"

echo -e "${B}[INFO] Please connect BOTH devices now...${NC}"
read
echo -e "${G}[TESTCASE] VALID CONFIG ${NC}"
./ascent -c "configs_for_tests/valid_config" "dryrun"
