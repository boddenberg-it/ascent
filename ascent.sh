#!/bin/bash

help() {
	echo -e "${Y}#################################################################"
	echo -e "#                                                               #"
	echo -e "#   ${B}~${G}:${B}~${Y}  A${R}ndroid ${Y}S${R}emiautomated ${Y}CE${R}llular ${Y}N${R}etwork ${Y}T${R}esting${Y}  ${B}~${G}:${B}~${Y}    #"
	echo -e "#                                                               #"
	echo -e "#  Ascent shall help testing cellular networks with 2 Android   #"
	echo -e "#  devices by only ovserving them - no physical interaction.    #"
	echo -e "#  It provides an adb-based CLI to call, send SMS and verify    #"
	echo -e "#  data. Although \"tests\" still have to be manual verified.     #"
	echo -e "#                                                               #"
	echo -e "#  There are ${R}two${Y} ways of using ascent.sh:                       #"
	echo -e "#                                                               #"
	echo -e "#       ${R}1st)${Y} ./ascent.sh ${G}\$arg${Y}   (ivokation with ${G}argument${Y})       #"
	echo -e "#       ${R}2nd)${Y} source ascent.sh   (${B}interactive mode${Y})              #"
	echo -e "#                                                               #"
	echo -e "#  ${R}1st)${Y} When ascent.sh is invoked, one can pass several         #"
	echo -e "#       of following arguments a.k.a. tests suites/cases:       #"
	echo -e "#                                                               #"
	echo -e "#           cases:  ${G}call${Y}, ${G}sms${Y}, ${G}data${Y}                             #"
	echo -e "#           suites: ${G}2g${Y}, ${G}3g${Y}                                      #"
	echo -e "#                                                               #"
	echo -e "#       All test cases will be executed on both test devices,   #"
	echo -e "#       i.e. Alice sends SMS to Bob and vice versa.             #"
	echo -e "#                                                               #"
	echo -e "#  ${R}2nd)${Y} When ascent.sh is sourced, one can use invokations      # "
	echo -e "#       described in ${R}1st${Y} as well. Additionally one can use      #"
	echo -e "#       test short cuts, where devices have to be specified:    #"
	echo -e "#                                                               #"
	echo -e "#           ${B}sms \$d0 \$d1${Y}                                         #"
	echo -e "#           ${B}call \$d1 \$d0${Y}                                        #"
	echo -e "#           ${B}ping \$d1 ${G}<IP|URL>${Y}                                   #"
	echo -e "#                                                               #"
  echo -e "#  But first, you need to create a \"config\" file, within the    #"
	echo -e "#  directory from which ascent is invoked/sourced as follows:   #"
	echo -e "#                                                               #"
	echo -e "#  ${R}<d0_android_serial>${Y}=${R}<d0_phone_number>${Y}=${R}<d0_name>${Y}              #"
	echo -e "#  ${R}<d1_android_serial>${Y}=${R}<d1_phone_number>${Y}=${R}<d1_name>${Y}              #"
	echo -e "#                                                               #"
	echo -e "#################################################################${NC}"
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
		echo -e "${R}[ERROR] not both devices are connected!${NC}"
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

# interactive helpers
reset() {
	go_to_homescreen
}

adb0() {
	adb -s "$(serial_of $d0)" $@
}

adb1() {
	adb -s "$(serial_of $d1)" $@
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
NC="\033[0m"
R="\033[0;31m"
G="\033[0;32m"
B="\033[0;35m"
Y="\033[1;33m"

# only one char is allowed in fact of using cut, please allign your config file accordingly.
DELIMITER="="

# the two android devices used for testing
if [ ! -f "$(pwd)/config" ]; then
	help
	echo
	echo -e "${R}[ERROR] no config file found, please provide one!${NC}"
	echo
	return 1
else
	d0="$(head -n 1 "$(pwd)"/config)"
	d1="$(tail -n 1 "$(pwd)"/config)"
fi

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
