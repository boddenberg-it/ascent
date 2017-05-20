#!/bin/bash

print_help() {
	echo -e "${Y}#################################################################"
	echo -e "#                                                               #"
	echo -e "#   ${B}~${G}:${B}~${Y}  A${R}ndroid ${Y}S${R}emiautomated ${Y}CE${R}llular ${Y}N${R}etwork ${Y}T${R}esting${Y}  ${B}~${G}:${B}~${Y}    #"
	echo -e "#                                                               #"
	echo -e "#  Ascent shall help testing cellular networks with 2 Android   #"
	echo -e "#  devices by only ovserving them - no physical interaction.    #"
	echo -e "#  It provides an adb-based CLI to call, send SMS and verify    #"
	echo -e "#  data. Although \"tests\" still have to be manually verified.   #"
	echo -e "#                                                               #"
	echo -e "#  There are ${R}two${Y} ways of using ascent.sh:                       #"
	echo -e "#                                                               #"
	echo -e "#       ${R}1st)${Y} ./ascent.sh ${G}\$arg${Y}   (ivokation with ${G}argument${Y})       #"
	echo -e "#       ${R}2nd)${Y} source ascent.sh   (${B}interactive mode${Y})              #"
	echo -e "#                                                               #"
	echo -e "#  ${R}1st)${Y} When ascent.sh is invoked, one can pass multiple        #"
	echo -e "#       of following arguments a.k.a. tests suites/cases:       #"
	echo -e "#                                                               #"
	echo -e "#           cases:  ${G}call${Y}, ${G}sms${Y}, ${G}data${Y}                             #"
	echo -e "#           suites: ${G}2g${Y}, ${G}3g${Y}                                      #"
	echo -e "#                                                               #"
	echo -e "#  ${R}2nd)${Y} When ascent.sh is sourced, one can use invokations      # "
	echo -e "#       described in ${R}1st${Y} as well. Additionally one can use      #"
	echo -e "#       test short cuts, where devices have to be specified:    #"
	echo -e "#                                                               #"
	echo -e "#           ${B}sms ${G}\$d0 \$d1${Y}                                         #"
	echo -e "#           ${B}call ${G}\$d1 \$d0${Y}                                        #"
	echo -e "#           ${B}ping ${G}\$d1 ${G}<IP|URL>${Y}                                   #"
	echo -e "#                                                               #"
	echo -e "#       Additionally, ascent provides some handy commands,      #"
	echo -e "#       when tests failed and devices need to be:               #"
	echo -e "#                                                               #"
	echo -e "#           ${B}unlock ${G}(\$d0||\$d1)${Y}                                   #"
	echo -e "#           ${B}reset (go_to_homescreen)${Y}                            #"
	echo -e "#           ${B}(adb1||adb2) ${G}shell input keyevent 66${Y}                #"
	echo -e "#                                                               #"
	echo -e "#  But first, you need to create a \"config\" file, within the    #"
	echo -e "#  directory from which ascent is invoked/sourced as follows:   #"
	echo -e "#                                                               #"
	echo -e "#       ${R}<d0_android_serial>${Y}=${R}<d0_phone_number>${Y}=${R}<d0_name>${Y}         #"
	echo -e "#       ${R}<d1_android_serial>${Y}=${R}<d1_phone_number>${Y}=${R}<d1_name>${Y}         #"
	echo -e "#                                                               #"
	echo -e "#  ${G}More information on https://github.com/blobbsen/ascent${Y}       #"
	echo -e "#                                                               #"
        echo -e "#################################################################${NC}"
}

sanity() {

	echo
	echo -e "${Y}[SANITY_CHECK] can config be found?${NC}"
	if [ ! -f "$(pwd)/config" ]; then
		echo -e "${R}[ERROR] no config file found, please provide one in CWD!${NC}"
		print_help
		return 1
	else
		d0="$(head -n 1 "$(pwd)"/config)"
		d1="$(tail -n 1 "$(pwd)"/config)"
		echo -e "${G}[INFO] config successfully parsed ($(pwd)/config)${NC}"
	fi

	echo -e "${Y}[SANITY_CHECK] are both devices connected?${NC}"
	err_codes=0
	adb devices | grep "$(serial_of "$d0")"
	err_codes=$((err_codes+$?))
	adb devices | grep "$(serial_of "$d1")"
	err_codes=$((err_codes+$?))

	if [ "$err_codes" -gt 0 ]; then
		echo -e "${R}[ERROR] not both devices are connected!${NC}"
		echo
		return 1
	else
		echo -e "${G}[INFO] adb connections successfully verified.${NC}"
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

ping() {
	echo -e "${Y}[TEST-DATA] ${G}$1${Y} tries to ping ${G}$2${Y} ${NC}"
	adb -s "$(serial_of "$1")" shell ping -c 3 "$2"
}

# interactive print_helpers (debugging)
d0() {
	echo $d0
}

d1() {
	echo $d1
}

adb0() {
	adb -s "$(serial_of $d0)" $@
}

adb1() {
	adb -s "$(serial_of $d1)" $@
}

reset() {
	go_to_homescreen
}

go_to_homescreen() {
	adb -s "$(serial_of "$d0")" shell input keyevent "$KEYCODE_HOME"
	adb -s "$(serial_of "$d1")" shell input keyevent "$KEYCODE_HOME"
}

# unlock() expects that there is no password or pattern to unlock the phone.
# A straight swipe from bottom to center should unlock the phone.
unlock() {
	# screen resolution
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

# only one character is allowed in fact of using cut,
# please allign your config file accordingly.
DELIMITER="="

# the two android devices used for testing


if [ $# -gt 0 ]; then
	# invoking script
	sanity
	if [ $? -eq 0 ]; then
		for var in "$@"; do
  			$var
			if [ $? -gt 0 ]; then print_help; fi
		done
	fi
else
	# sourcing script (interactive mode)
	print_help
	sanity
	echo -e "${Y}[INFO] sourcing $(dirname $0)/$(basename $0)${NC}"
	source "$(dirname $0)/$(basename $0)"
	# if $? -gt 0]; then

	# else
	#      source script $(dirname foo blakeks)
	# fi
fi
