#!/bin/bash

help() {
	echo "foo"
}

sanity() {

	echo
	echo -e "${YELLOW}[SANITY_CHECK] are all devices connected? ${NC}"
	err_codes=0
	adb devices | grep "$(serial_of $td_0)"
	err_codes=$((err_codes+$?))
	adb devices | grep "$(serial_of $td_1)"
	err_codes=$((err_codes+$?))

	if [ "$err_codes" -gt 0 ]; then
		echo
		echo -e "${RED}[ERROR] not all devices are not connected!!! ${NC}"
		echo
		exit 1
	else
		echo -e "${GREEN}[INFO] sanity check successful ${NC}"
	fi

	echo
}

# test wrappers
2g() {
	sms
	call
}

3g() {
	2g
	data
}

sms() {
	send_sms "$td_0" "$td_1"
	send_sms "$td_1" "$td_0"
}

data() {
	ping "$td_0" "8.8.8.8"
	ping "$td_1" "8.8.8.8"
}

call() {
	do_call "$td_0" "$td_1"
	do_call "$td_1" "$td_0"
}

# actual tests
send_sms() {

	if [ $# -ne 2 ]; then
		echo -e "${RED}[ERROR] You need to pass 2 arguments to send_sms()"
		echo
		echo "	send_sms \$sender_serial \$receiver_number ${NC}"
		echo
		exit 1
	fi

	go_to_homescreen
	echo -e "$YELLOW[TEST] ${GREEN}$1${YELLOW} sends SMS to ${GREEN}$2${YELLOW} ${NC}"

	adb -s "$(serial_of $1)" shell am start -a android.intent.action.SENDTO \
		-d sms:"$(number_of $2)" --es sms_body "test_intent" --ez exit_on_sent true
	sleep 0.3
  adb -s "$(serial_of $1)" shell input text "test_input"
	sleep 0.2
	adb -s "$(serial_of $1)" shell input keyevent "$KEYCODE_DPAD_RIGHT"
	sleep 0.2
	adb -s "$(serial_of $1)" shell input keyevent "$KEYCODE_ENTER"

	go_to_homescreen
	echo
}

do_call() {

	go_to_homescreen

	echo -e "${YELLOW}[TEST] ${GREEN}$1${YELLOW} calls ${GREEN}$2${YELLOW} ${NC}"
	adb -s "$(serial_of $1)" shell am start -a android.intent.action.CALL \
                -d tel:"$(number_of $2)"

	echo -e "${YELLOW}	${BLUE}[INPUT]${YELLOW} does it ring? (no|ENTER)${NC}"
	read does_it_ring

	if [[ "$does_it_ring" == *"n"* ]]; then
		echo -e "${RED} 	[ERROR] call could not be established! ${NC}"
	else
		echo -e "${YELLOW}	[INFO] ${GREEN}$2${YELLOW} accepts call${NC}"
		adb -s "$(serial_of $2)" shell input keyevent "$KEYCODE_CALL"

		echo -e "${YELLOW}	${BLUE}[INPUT]${YELLOW} enough of talking? ${NC}"
		read  enough_of_talking

		echo -e "${YELLOW}	[INFO] ${GREEN}$1${YELLOW} ends call ${NC}"
		adb -s "$(serial_of $1)" shell  input keyevent "$KEYCODE_ENDCALL"
		sleep 3 # Nexus 5 takes ages
		echo "trying to unlock"
		unlock_screen "$1"
	fi

	go_to_homescreen
	echo
}

ping() {
	echo -e "${YELLOW}[TEST] ${GREEN}$1${YELLOW} tries to ping ${GREEN}$2${YELLOW} ${NC}"
	adb -s $(serial_of $1) shell ping -c 3 "$2"
	echo
}

# adb "flow" helpers
go_to_homescreen() {
	adb -s "$(serial_of $td_0)" shell input keyevent "$KEYCODE_HOME"
	adb -s "$(serial_of $td_1)" shell input keyevent "$KEYCODE_HOME"
}

unlock_screen() {
	screen="$(adb -s $(serial_of $1) shell dumpsys display | grep deviceWidth \
		| awk -F"deviceWidth=" '{print $2}' | head -n 1)"

	width="$(echo $screen | cut -d ',' -f1)"
	height="$(echo $screen | cut -d '=' -f2 | cut -d '}' -f1)"

	x=$((width/2))
	y1=$((height-20))
	y2=$((height/2))

	adb -s "$(serial_of $1)" shell input keyevent "$KEYCODE_POWER"
	sleep 1
	adb -s "$(serial_of $1)" shell input swipe "$x" "$y1" "$x" "$y2"
}

# a bit OOP'ish to not care about whether serial or number has to be passed
number_of() {
	echo $(echo $1 | cut -d "$DELIMITER" -f2)
}

serial_of() {
	echo $(echo $1 | cut -d "$DELIMITER" -f1)
}

# https://developer.android.com/reference/android/view/KeyEvent.html
KEYCODE_HOME=3
KEYCODE_CALL=5
KEYCODE_ENDCALL=6 # locks screen at the same time!
KEYCODE_DPAD_RIGHT=22
KEYCODE_POWER=26
KEYCODE_ENTER=66

# colours
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;35m'
YELLOW='\033[1;33m'

# only one char is allowed in fact of using cut.
# please allign your config file accordingly.
DELIMITER="="

# the two android devices for testing
td_0="$(head -n 1 $(pwd)/config)"
td_1="$(tail -n 1 $(pwd)/config)"

if [ $# -gt 0 ]; then # invokation with args
	sanity
	for var in "$@"; do
  	$var
		if [ $? -gt 0 ]; then help; fi
	done
else
	help
	sanity
fi
