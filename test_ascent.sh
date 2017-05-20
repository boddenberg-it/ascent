#!/bin/bash
#
# Simple script to allow some testing (mainly verifying config parsing).

# colors
NC="\033[0m"
R="\033[0;31m"
G="\033[0;32m"
B="\033[0;35m"

# counting all errors occuring in test run
errors=0

test_case() {
  echo
  echo -e "${B}[TESTCASE] $1 ${NC}"
  ./ascent -c "configs_for_tests/$2" "testing"

  if [ $? -ne $3 ]; then
    errors=$((errors+1))
    echo -e "${R}[TESTCASE] $1 FAILED!!!${NC}"
    echo
  else
    echo -e "${G}[TESTCASE] $1 SUCCEEDED${NC}"
    echo
  fi
}

summarise_suites() {
  echo
  if [ $errors -eq 0 ]; then
    echo -e "${G}[RESULT] ALL TESTCASES DID PASS SUCCESSFULLY :)${NC}"
    echo
  else
    echo -e "${R}[RESULT] $errors TESTCASE(S) FAILED !!!${NC}"
    echo
    # return amount of errors in case one wants to evaluate it programmatically
    exit "$errors"
  fi
}

test_case "EMPTY CONFIG" "empty_config" 1

test_case "INVALID CONFIG" "invalid_config" 1

echo -e "${B}[INFO] Please connect ONE device now...${NC}"; read
test_case "ONLY ONE DEVICE IS CONNECTED" "valid_config" 1

echo -e "${B}[INFO] Please connect BOTH devices now...${NC}"; read
test_case "ONLY ONE DEVICE IS CONNECTED" "valid_config" 0

summarise_suites
