#!/bin/bash

print_help() {

	print_interactive_mode_banner

	echo -e "#  There are ${R}two${Y} ways of using ascent.sh:                       #"
	echo -e "#                                                               #"
	echo -e "#       ${R}1st)${Y} ${GRAY}./ascent.sh ${G}arg(s)${Y}                                 #"
	echo -e "#       ${R}2nd)${Y} ${GRAY}source ascent.sh   ${B}(interactive mode)${Y}              #"
	echo -e "#                                                               #"
	echo -e "#  But first, one need to create a ascent.cfg file inside the   #"
	echo -e "#  directory from which ascent is invoked/sourced or create     #"
	echo -e "#  ~/.ascent holding following information:                     #"
	echo -e "#                                                               #"
	echo -e "#       ${GRAY}device_0=${G}<android_serial>${GRAY}=${G}<msisdn>${GRAY}=${G}<name>${Y}               #"
	echo -e "#       ${GRAY}device_1=${G}<android_serial>${GRAY}=${G}<msisdn>${GRAY}=${G}<name>${Y}               #"
	echo -e "#                                                               #"
	echo -e "#  Alterantively, one can also pass config path as follows:     #"
	echo -e "#                                                               #"                                                             #"
	echo -e "#       ${GRAY}./ascent -c ${G}<path_to_config_file>${Y} ${G}arg(s)${Y}                #"
	echo -e "#                                                               #"
	echo -e "#  ${R}1st)${Y} When ascent.sh is invoked, one can pass several         #"
	echo -e "#       of following arguments (tests suites/cases):            #"
	echo -e "#                                                               #"
	echo -e "#           cases:  ${G}call${Y}, ${G}sms${Y}, ${G}data${Y}                             #"
	echo -e "#           suites: ${G}2g${Y} (call + sms), ${G}3g${Y} (call + sms + data)     #"
	echo -e "#                                                               #"
	echo -e "#  ${R}2nd)${Y} When ascent.sh is sourced, one can use invokations      # "
	echo -e "#       described in ${R}1st${Y} as well. Additionally one can use      #"
	echo -e "#       commands, where devices can be be specified:            #"
	echo -e "#                                                               #"
	echo -e "#           ${B}sms  ${G}\$d0 \$d1${Y}                                        #"
	echo -e "#           ${B}call ${G}\$d1 \$d0${Y}                                        #"
	echo -e "#           ${B}ping ${G}\$d1 ${G}<IP|URL>${Y}                                   #"
	echo -e "#                                                               #"
	echo -e "#       Additionally, ascent provides some handy commands,      #"
	echo -e "#       when tests failed and devices need to be debugged:      #"
	echo -e "#                                                               #"
	echo -e "#           ${B}help${Y}                                                #"
	echo -e "#           ${B}sanity${Y}                                              #"
	echo -e "#           ${B}go_to_homescreen${Y}                                    #"
	echo -e "#           ${B}unlock_device ${G}(\$d0||\$d1)${Y}                            #"
	echo -e "#           ${B}(adb0||adb1) ${G}shell input keyevent 66${Y}                #"
	echo -e "#                                                               #"
	echo -e "#  ${Y}More information on https://github.com/boddenberg-it/ascent${Y}  #"
	echo -e "#                                                               #"
  echo -e "#################################################################${NC}"
}

print_interactive_mode_banner() {
	echo -e "${Y}#################################################################"
	echo -e "#                                                               #"
	echo -e "#   ${B}~${G}:${B}~${Y}  ${R}A${GRAY}ndroid ${R}S${GRAY}emiautomated ${R}CE${GRAY}llular ${R}N${GRAY}etwork ${R}T${GRAY}esting${Y}  ${B}~${G}:${B}~${Y}    #"
	echo -e "#                                                               #"
	echo -e "#  Ascent shall help testing cellular networks with 2 Android   #"
	echo -e "#  devices by only ovserving them - no physical interaction.    #"
	echo -e "#  It provides an adb-based CLI to call, send SMS and verify    #"
	echo -e "#  data. Although \"tests\" still have to be manually verified.   #"
	echo -e "#                                                               #"
	echo -e "#  author:  André Boddenberg (ascent@boddenberg.it)             #"                                                          #"
	echo -e "#  version: $ASCENT_VERSION                                                 #"
	echo -e "#                                                               #"
	if [ $# -gt 0 ]; then
		echo -e "#################################################################${NC}"
	fi
}

# Kind of OOP'ish approach to not care about whether serial or number has to
# be passed. Thus enabling a smooth interactive mode by only specifying $d0
# or $d1 and not its serial or number, which would look like:
#
#      $ source ascent.sh
#      $ call $d0_serial $d1_number

number_of() {
	echo "$1" | cut -d "$DELIMITER" -f3
}

serial_of() {
	echo "$1" | cut -d "$DELIMITER" -f2
}

# https://developer.android.com/reference/android/view/KeyEvent.html
KEYCODE_HOME=3
KEYCODE_CALL=5
KEYCODE_ENDCALL=6
KEYCODE_DPAD_RIGHT=22
KEYCODE_POWER=26
KEYCODE_ENTER=66

# colours
NC="\033[0m"
R="\033[0;31m"
G="\033[0;32m"
B="\033[0;35m"
Y="\033[1;33m"
GRAY="\033[0;37m"

# Feel free to change, but only one character is allowed in fact of using cut.
# Remmber to allign config file accordingly after changing delimiter.
DELIMITER="="

# default directory is the current working directory
ASCENT_CONFIG="$(pwd)/ascent.cfg"
ASCENT_VERSION="0.1"

sanity() {
	echo
	echo -e "${Y}[SANITY_CHECK] can config be found?${NC}"

	if [ ! -f "$ASCENT_CONFIG" ]; then
		echo
		echo -e "${R}[ERROR] No config file found! Please provide one in current working "
		echo -e "        directory or pass on e.g.: "
		echo
		echo -e "            ./ascent -c ~/.ascent${NC}"
		echo
		export ASCENT_CONFIG=""
		return 1
	else
		# parsing config
		d0="$(cat "$ASCENT_CONFIG" | grep device_0= )"
		d1="$(cat "$ASCENT_CONFIG" | grep device_1= )"
		# check (unprecisely) whether d0 and d1 hold "enough" information
		if [ ${#d0} -gt 20 ] && [ ${#d1} -gt 20 ]; then
			echo -e "${G}[INFO] config $ASCENT_CONFIG has been parsed:${NC}"
			cat "$ASCENT_CONFIG"
			echo
		else
			echo
			echo -e "${R}[ERROR] content of config file seems corrupted, thus it could"
			echo -e "        not been parsed. Content of config file:${NC}"
			cat "$ASCENT_CONFIG"
			echo
			echo -e "${Y}config path: $ASCENT_CONFIG${Y}"
			echo
			return 1
		fi
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

# TEST FUNCTIONS

# send_sms passes text message already via intent, but additionally it sends
# another text via adb to ensure that sms holds text. On some devices one can
# not pass sms text as intent.
#
# Note: The SMS Messaging (AOSP) app works best with ascent.sh
send_sms() {
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

# TEST WRAPPER
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
	ping "$d0" 8.8.8.8
  ping "$d1" 8.8.8.8
}

2g() {
	sms
	call
}

3g() {
	2g
	data
}

# INTERACTIVE MODE HELPER FUNCTIONS
adb0() {
	adb -s "$(serial_of $d0)" $@
}

adb1() {
	adb -s "$(serial_of $d1)" $@
}

# Resets both devices at the same time by killing all activities and
# jumping to the home screen.
go_to_homescreen() {
	# TODO: add killing all opened activities :)
	adb -s "$(serial_of "$d0")" shell input keyevent "$KEYCODE_HOME"
	adb -s "$(serial_of "$d1")" shell input keyevent "$KEYCODE_HOME"
}

help() {
	print_help
}

# Some devices may require adb root access to ping.
# ping() is used by "data" test-wrapper.
ping() {
	echo -e "${Y}[TEST-DATA] ${G}$1${Y} tries to ping ${G}$2${Y} ${NC}"
	adb -s "$(serial_of "$1")" shell ping -c 3 "$2"
}

# unlock_device() expects that there is no password or pattern to unlock the phone.
# A straight swipe from bottom to center should unlock the phone.
unlock_device() {
	if [ $# -ne 1 ]; then
		echo
		echo -e "${R}[ERROR] You must specify which device (\$d0||\$d1) should be unlocked!"
		echo
		return 1
	fi

	screen_res="$(adb -s $(serial_of $1) shell dumpsys display | grep deviceWidth \
		| awk -F"deviceWidth=" '{print $2}' | head -n 1)"

	width="$(echo $screen_res | cut -d ',' -f1)"
	height="$(echo $screen_res | cut -d '=' -f2 | cut -d '}' -f1)"

	# swipe coordinates - from bottom to center
	x=$((width/2))
	y1=$((height-20))
	y2=$((height/2))

	adb -s "$(serial_of $1)" shell input keyevent "$KEYCODE_POWER"
	sleep 1
	adb -s "$(serial_of $1)" shell input swipe "$x" "$y1" "$x" "$y2"
}

# INIT

# check whether global config file is available
if [ -f ~/.ascent ]; then
		export ASCENT_CONFIG=~/.ascent
fi
# Check whether config file is passed or user requests help?
if [ "$1" = "-c" ]; then
	# Simply export ASCENT_CONFIG. sanity() will take care about wrong configs.
	export ASCENT_CONFIG="$2"
	# Cut off first two arguments to simply continue script.
	shift 2

elif [ "$1" = "-h" ] || [[ "$1" == *"help"* ]]; then
	print_help
	exit 0
fi

# invokation with test-case/suite
if [ $# -gt 0 ]; then
	# Enable error code evaluation for test_ascent.sh.
	if [ "$1" = "testing" ]; then
		sanity
		exit $?
	else
		sanity
	fi

	if [ $? -eq 0 ]; then
		# Executing each test-case/suite sequentially.
		for test in "$@"; do
				$test
			# Abort if passed test-case/suite i.e. command, could not be found!
			if [ $? -gt 0 ]; then
				print_help
				echo
				echo "${R} [ERROR] test-case/suite: \"$test\" is not available"
				echo
				exit 1
			fi
		done
	fi
else
	# interactive mode (only when sourced or invoked without test-case/suite)
  print_interactive_mode_banner "interactive_mode"
	sanity
fi
