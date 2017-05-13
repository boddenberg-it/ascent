#!/bin/bash

help() {
	echo -e "${Y}#######################################################"
	echo -e "#" ${b}A${bo}ndroid Semiautomated CEllular Network Testing
	echo -e "#"
	echo -e "#"
	echo -e "#"
	echo -e "#######################################################${NC}"
}

sanity() {
	echo
	echo -e "${Y}[SANITY_CHECK] are both devices connected?${NC}"

	err_codes=0
	adb devices | grep "$(serial_of "$d0")"
	err_codes=$((err_codes+$?))
	adb devices | grep "$(serial_of "$d1")"
	err_codes=$((err_codes+$?))

	if [ "$err_codes" -gt 0 ]; then
		echo
		echo -e "${R}[ERROR] not all devices are not connected!!!${NC}"
		echo
		return 1
	else
		echo -e "${G}[INFO] sanity check successful${NC}"
		echo
	fi
}

#  test wrapper
2g() {
	sms
	call
}

3g() {
	2g
	data
}

sms() {
	if [ $# -eq 2 ]; then
		send_sms "$1" "$2"
	else
		send_sms "$d0" "$d1"
		send_sms "$d1" "$d0"
	fi
}

call() {
	if [ $# -eq 2 ]; then
		do_call "$1" "$2"
	else
		do_call "$d0" "$d1"
		do_call "$d1" "$d0"
	fi
}

data() {
		ping "$d0" "8.8.8.8"
		ping "$d1" "8.8.8.8"
}

# actual tests
send_sms() {
	if [ $# -ne 2 ]; then
		echo -e "${R}[ERROR] You need to pass 2 arguments to send_sms()"
		echo
		echo "	send_sms \$sender_serial \$receiver_number ${NC}"
		echo
		exit 1
	fi

	go_to_homescreen
	echo -e "$Y[TEST-SMS] ${G}$1${Y} sends SMS to ${G}$2${Y} ${NC}"

	adb -s "$(serial_of "$1")" shell am start -a android.intent.action.SENDTO \
		-d sms:"$(number_of "$2")" --es sms_body "test_intent" --ez exit_on_sent true

	sleep 0.2
  adb -s "$(serial_of "$1")" shell input text "test_input"
	sleep 0.2
	adb -s "$(serial_of "$1")" shell input keyevent "$KEYCODE_DPAD_RIGHT"
	sleep 0.2
	adb -s "$(serial_of "$1")" shell input keyevent "$KEYCODE_ENTER"

	go_to_homescreen
	echo
}

do_call() {
	go_to_homescreen
	echo -e "${Y}[TEST-CALL] ${G}$1${Y} calls ${G}$2${Y} ${NC}"

	adb -s "$(serial_of "$1")" shell am start -a android.intent.action.CALL \
                -d tel:"$(number_of "$2")"

	echo -e "${Y}	${B}[INPUT]${Y} does it ring? (no|ENTER)${NC}"
	read does_it_ring

	if [[ "$does_it_ring" == *"n"* ]]; then
		echo -e "${R} 	[ERROR] call could not be established! ${NC}"
	else
		echo -e "${Y}	[INFO] ${G}$2${Y} accepts call${NC}"
		adb -s "$(serial_of "$2")" shell input keyevent "$KEYCODE_CALL"

		echo -e "${Y}	${B}[INPUT]${Y} enough of talking? ${NC}"
		read

		echo -e "${Y}	[INFO] ${G}$1${Y} ends call ${NC}"
		adb -s "$(serial_of "$1")" shell  input keyevent "$KEYCODE_ENDCALL"
	fi

	go_to_homescreen
	echo
}

ping() {
	echo -e "${Y}[TEST-DATA] ${G}$1${Y} tries to ping ${G}$2${Y} ${NC}"
	adb -s "$(serial_of "$1")" shell ping -c 3 "$2"
	# TODO: check whether "operation permitted" of s3, can be caught and then 'adb shell su -c ping'
	echo
}

# adb "flow" helpers
go_to_homescreen() {
	adb -s "$(serial_of "$d0")" shell input keyevent "$KEYCODE_HOME"
	adb -s "$(serial_of "$d1")" shell input keyevent "$KEYCODE_HOME"
}

# a bit OOP'ish to not care about whether serial or number has to be passed
number_of() {
	echo "$1" | cut -d "$DELIMITER" -f2
}

serial_of() {
	echo "$1" | cut -d "$DELIMITER" -f1
}

# https://developer.android.com/reference/android/view/KeyEvent.html
KEYCODE_HOME=3
KEYCODE_CALL=5
KEYCODE_ENDCALL=6
KEYCODE_DPAD_RIGHT=22
KEYCODE_ENTER=66

# colours
NC='\033[0m'
R='\033[0;31m'
G='\033[0;32m'
B='\033[0;35m'
Y='\033[1;33m'

# only one char is allowed in fact of using cut.
# please allign your config file accordingly.
DELIMITER="="

# the two android devices used for testing
d0="$(head -n 1 "$(pwd)"/config)"
d1="$(tail -n 1 "$(pwd)"/config)"

if [ $# -gt 0 ]; then
	sanity
	for var in "$@"; do
  	$var
		if [ $? -gt 0 ]; then help; fi
	done
else
	help
	sanity
fi
