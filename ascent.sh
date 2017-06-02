#!/bin/bash

ASCENT_VERSION="0.1"

# colours
NC="\033[0m"
R="\033[0;31m"
G="\033[0;32m"
B="\033[0;35m"
Y="\033[1;33m"
GRAY="\033[0;37m"

# LOG HELPER
log_info() {
	echo -e "${Y}[INFO] $1 ${NC}"
}

log_error() {
	echo -e "${R}[ERROR] $1${NC}\n"
	# "resetting" devices to avoid flaky states
	go_to_homescreen
}

init_test() {
	go_to_homescreen
	echo -e "\n${Y}[TEST-$1] $2 ${NC}"
}

test_success() {
	echo -e "${G}[TEST-$1] SUCCESS${NC}\n"
	go_to_homescreen
}

print_help() {

	print_interactive_mode_banner

	echo -e "#  There are ${R}two${Y} ways of using ascent.sh:                       #"
	echo -e "#                                                               #"
	echo -e "#       ${R}1st)${Y} ${GRAY}./ascent.sh ${G}arg(s)${Y}                                 #"
	echo -e "#       ${R}2nd)${Y} ${GRAY}source ascent.sh   ${B}(interactive mode)${Y}              #"
	echo -e "#                                                               #"
	echo -e "#  But first, one need to create ascent.cfg file, which can     #"
	echo -e "#  be placed in ~/.ascent or passed when invoking:              #"
	echo -e "#                                                               #"
	echo -e "#       ${GRAY}./ascent -c ${G}<path_to_config_file>${Y} ${G}arg(s)${Y}                #"
	echo -e "#                                                               #"
	echo -e "#  Following information need to be provided by config file:    #"
	echo -e "#                                                               #"
	echo -e "#       ${G}serial_0=05cd98e0f0fd7bc8${Y}                               #"
	echo -e "#       ${G}msisdn_0=1234${Y}                                           #"
	echo -e "#       ${G}name_0=s7${Y}                                               #"
	echo -e "#                                                               #"
	echo -e "#       ${G}serial_1=4ef2d43176795a51${Y}                               #"
	echo -e "#       ${G}msisdn_1=5678${Y}                                           #"
	echo -e "#       ${G}name_1=nexus6${Y}                                           #"
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
	echo -e "#           ${B}sms  ${G}d0 d1${Y}                                          #"
	echo -e "#           ${B}call ${G}d1 d0${Y}                                          #"
	echo -e "#           ${B}ping ${G}d1 ${G}<IP|URL>${Y}                                    #"
	echo -e "#                                                               #"
	echo -e "#       Furthermore, ascent provides some handy commands,       #"
	echo -e "#       when tests failed and devices need to be debugged:      #"
	echo -e "#                                                               #"
	echo -e "#           ${B}help${Y}                                                #"
	echo -e "#           ${B}sanity${Y}                                              #"
	echo -e "#           ${B}go_to_homescreen${Y}                                    #"
	echo -e "#                                                               #"
	echo -e "#           ${B}unlock_device ${G}(d0||d1)${Y}                              #"
	echo -e "#           ${B}(adb0||adb1) ${G}shell input keyevent 66${Y}                #"
	echo -e "#                                                               #"
	echo -e "#  ${Y}More information on https://github.com/boddenberg-it/ascent${Y}  #"
	echo -e "#                                                               #"
	echo -e "#################################################################${NC}"
}

print_interactive_mode_banner() {
	echo -e "${Y}#################################################################"
	echo -e "#  Ascent shall help testing cellular networks (2/3/4G) with    #"
	echo -e "#  two Android devices as subscribers (MS/UE). It provides an   #"
	echo -e "#  adb-based CLI to test call and SMS functionalities (CS),     #"
	echo -e "#  as well as data + internet connection (PS).                  #"
	echo -e "#                                                               #"
	echo -e "#  author:  André Boddenberg (ascent@boddenberg.it)             #"
	echo -e "#  version: $ASCENT_VERSION                                                #"
	echo -e "#                                                               #"
	if [ $# -gt 0 ]; then
		echo -e "#################################################################${NC}"
	fi
}

sanity() {

	echo -e "\n${Y}[SANITY_CHECK] does config exist?${NC}"

	if [ ! -f "$ASCENT_CONFIG" ]; then
		echo -e "\n${R}[ERROR] No config file found! Please provide one in ~/.ascent"
		echo -e "        or pass on e.g.:\n"
		echo -e "            ./ascent -c ~/.ascent${NC}\n"
		return 1

	else
		log_info "sourcing $ASCENT_CONFIG"
		source "$ASCENT_CONFIG"

		missing=""

		if [ -z ${serial_0+x} ]; then missing="$missing serial_0"; fi
		if [ -z ${msisdn_0+x} ]; then missing="$missing msisdn_0"; fi
		if [ -z ${name_0+x} ]; then missing="$missing name_0"; fi

		if [ -z ${serial_1+x} ]; then missing="$missing serial_1"; fi
		if [ -z ${msisdn_1+x} ]; then missing="$missing msisdn_1"; fi
		if [ -z ${name_1+x} ]; then missing="$missing name_1"; fi

		if [ ${#missing} -gt 0 ]; then
			log_error "Config does not hold following information: $missing"
			return 1
		fi

	fi

	echo -e "${Y}[SANITY_CHECK] are both devices connected?${NC}"
	err_codes=0
	adb devices | grep "$serial_0"
	err_codes=$((err_codes+$?))
	adb devices | grep "$serial_1"
	err_codes=$((err_codes+$?))

	if [ "$err_codes" -gt 0 ]; then
		log_error "not both devices are connected!"
		return 1
	else
		log_info "adb connections successfully verified"
	fi

	echo -e "${G}[SANITY_CHECK] SUCCESS${NC}\n"
}

# ADB WRAPPER
# https://developer.android.com/reference/android/view/KeyEvent.html
KEYCODE_HOME=3
KEYCODE_CALL=5
KEYCODE_ENDCALL=6
KEYCODE_DPAD_RIGHT=22
KEYCODE_POWER=26
KEYCODE_ENTER=66

adb_shell() {
	adb -s "$1" wait-for-device shell $@
}

adb_keyevent() {
	adb -s "$1" shell input keyevent "$2"
}

# Note: SMS Messaging (AOSP) app is required!
adb_send_sms(){
	adb -s "$1" shell am start -a android.intent.action.SENDTO \
		-d sms:"$2" --es sms_body "intent_text" --ez exit_on_sent true

	sleep 0.2
	adb_input_text "$1" "input_text"
	sleep 0.2
	adb_keyevent "$1" "$KEYCODE_DPAD_RIGHT"
	sleep 0.2
	adb_keyevent "$1" "$KEYCODE_ENTER"
}

adb_input_text() {
	adb -s "$1" shell input text "$2"
}

adb_call() {
	adb -s "$1" shell am start -a android.intent.action.CALL -d tel:"$2"
}

adb_ping() {

	ping_count=3
	if [ ! -z ${3+x} ]; then ping_count="$3"; fi

	# freaky string, because two commands can only be passed to adb shell at
	# once within single quotes, but passing URL and ping count is necessary.
  output=$(adb -s $1 shell 'ping -c '"$ping_count"' '"$2"'; echo $?')

	if [[ $(echo $output | tail -1) != *"0"* ]]; then return 1; fi
}

adb_swipe() {
	adb -s "$1" shell input swipe "$2" "$3" "$4" "$5"
}

adb_clear_logcat() {
		# TODO: introduce d0 d1
		if [ $# -eq 1 ]; then
    	adb -s "$1" logcat -c
		else
			adb -s "$serial_0" logcat -c
			adb -s "$serial_1" logcat -c
		fi
}

# 0 nothing, 1 gets called, 2 is calling
adb_check_callState() {

	timeout=$(date +%s)

	# default or passed timeout
	if [ ${3+z} ]; then
		timeout=$((timeout+$3))
	else
		timeout=$((timeout+25))
	fi

	while [ "$(date +%s)" -lt "$timeout" ]; do
		cs=$(adb -s $1 shell dumpsys telephony.registry | grep "mCallState=$2")
		if [ ${#cs} -gt 0 ]; then return 0; fi
	done

	return 1
}

# TODO: clean up, make output pretty (check all lines, new line after each tests, plus new line after sourcing our invoking stuff)
#				check interactive mode, does everything work out fine? (can timeouts be passed?)
#       After finally pushed, think about introduing getting APN and pinging to distinguish between DATA-TEST INTERNET-TEST!

adb_grep_logcat() {

	timeout=$(date +%s)

	# default or passed timeout
	if [ ${3+z} ]; then
		timeout=$((timeout+$3))
	else
		# (recommended) default timeout of 15 s
		timeout=$((timeout+15))
	fi

	while [ "$(date +%s)" -lt "$timeout" ]; do
		# -d is necessary, because otherwise adb does not terminate on its own.
		adb -s "$1" logcat -d > "logcat_$1.txt"

		if grep -E "$2" < logcat_$1.txt > /dev/null; then
			echo "$(grep -E "$2" < logcat_$1.txt | wc -l)"
			rm "logcat_$1.txt"
			return 0;
		fi

	done

	rm "logcat_$1.txt"
	return 1
}

# TODO: get rid of this function and use only adb_grep_logcat!!!
#				only needed for send_sms' sms request verification to CN. :/
adb_grep_logcat_twice() {
	timeout=$(date +%s)

	# default or passed timeout
	if [ ${3+z} ]; then
		timeout=$((timeout+$3))
	else
		# (recommended) default timeout of 15 s
		timeout=$((timeout+15))
	fi

	while [ "$(date +%s)" -lt "$timeout" ]; do
		# -d is necessary, because otherwise adb does not terminate on its own.
		adb -s "$1" logcat -d > "logcat_$1.txt"

		if [ $(grep -E "$2" < logcat_$1.txt | wc -l) -eq 2 ]; then
			rm "logcat_$1.txt"
			return 0;
		fi

	done

	rm "logcat_$1.txt"
	return 1
}

# TEST FUNCTIONS

# send_sms passes text message already via intent, but additionally it sends
# another text via adb to ensure that sms holds text. On some devices one can
# not pass sms text as intent.
#
# Note: The SMS Messaging (AOSP) app works best with ascent.sh
send_sms() {
	go_to_homescreen
	adb_clear_logcat

	init_test "SMS" "$1 sends SMS to $2"
	adb_send_sms "$1" "$2" "test_input"

	# verification that SMS request could be sent(?)
	if adb_grep_logcat "$1" ".*Mms.*onStart:.*mResultCode: -1 = Activity.RESULT_OK" > /dev/null; then
			log_info "$1 tries to send SMS to CN..."
	else
			log_error "TIMEOUT $1 SMS could not be send (yet) to $2"
			return 1
	fi

	# verification that SMS request could be sent(?)
	if adb_grep_logcat_twice "$1" ".*Mms.*onStart:.*mResultCode: -1 = Activity.RESULT_OK" > /dev/null; then
			log_info "$1 successfully sent SMS to CN"
	else
			log_error "TIMEOUT $1 SMS could not be send (yet) $2"
			return 1
	fi

	# verifying that reciever received SMS
	if adb_grep_logcat "$3" "handleSmsReceived" > /dev/null; then
		log_info "$3 received SMS of $1"
	else
		log_error "TIMEOUT $1 SMS could not be received (yet) $2"
		return 1
	fi

	test_success "SMS"
}

do_call() {

	init_test "CALL" "$1 calls $2"

	adb_call "$1" "$2"; sleep 1

	# call intent verification
	if adb_check_callState "$1" "2" > /dev/null; then
		log_info "call intent successful"
	else
		log_error "call intent failed"
		return 1
	fi

	# verification whether call reached its destination
	if adb_check_callState "$3" "1" > /dev/null; then
		log_info "$2 accepts call"
		adb_keyevent "$3" "$KEYCODE_CALL"
	else
		# canceling call-request in case it's still active
		if adb_check_callState "$1" "2" > /dev/null; then
			adb_keyevent "$1" "$KEYCODE_ENDCALL"
		fi

		log_error "call could not be established"
		return 1
	fi

	# holding line
	sleep 3
	log_info "$1 ends call"
	adb_keyevent "$1" "$KEYCODE_ENDCALL"

	test_success "CALL"

}

do_icall() {

	init_test "CALL" "$1 calls $2"

	adb_call "$1" "$2"

	echo -e "${B}[INPUT]${Y} does it ring? (no|ENTER)${NC}"
	read does_it_ring

	if [[ "$does_it_ring" == *"no" ]]; then
		# canceling call-request in case it's still active
		if adb_check_callState "$1" "2" > /dev/null; then
			adb_keyevent "$1" "$KEYCODE_ENDCALL"
		fi
		log_error "call could not be established"

	else
		log_info "$2 accepts call"
		adb_keyevent "$3" "$KEYCODE_CALL"

		echo -e "${B}[INPUT]${Y} enough of talking? ${NC}"
		read

		log_info "$1 ends call"
		adb_keyevent "$1" "$KEYCODE_ENDCALL"
	fi

	go_to_homescreen
}


# test wrapper for interactive mode
generic_test() {
	if [ $# -eq 2 ]; then
		if [ "$2" = "d0" ]; then
			$1 "$serial_0" "$msisdn_1" "$serial_1"
		else
			$1 "$serial_1" "$msisdn_0" "$serial_0"
		fi
	else
		$1 "$serial_0" "$msisdn_1" "$serial_1"
		$1 "$serial_1" "$msisdn_0" "$serial_0"
	fi
}

sms() {
	generic_test "send_sms" $@
}

call() {
	generic_test "do_call" $@
}

call() {
	generic_test "do_icall" $@
}

data() {
	test_ping $serial_0 8.8.8.8
	test_ping $serial_1 8.8.8.8
}

test_ping() {
	init_test "DATA" "$1 tries to ping $2"

	adb_ping $@

	if [ $? -eq 0 ]; then
		test_success "DATA"
	else
		log_error "FAILURE"
	fi
}

2g() {
	sms
	call
}

3g() {
	2g
	data
}

4G() {
	3G
}

# INTERACTIVE MODE HELPER FUNCTIONS
help() {
	print_help
}

adb0() {
	adb wait-for-device -s "$serial_0" "$@"
}

adb1() {
	adb wait-for-device -s "$serial_1" "$@"
}

# jumping to the home screen.
go_to_homescreen() {
	# TODO: add killing all opened activities...
	adb_keyevent "$serial_0" "$KEYCODE_HOME"
	adb_keyevent "$serial_1" "$KEYCODE_HOME"
}

# unlock_device() expects that there is no password or pattern to unlock the phone.
# A straight swipe from bottom to center should unlock the phone.
unlock_device() {
	serial=""

	if [ $# -ne 1 ]; then
		log_error "You must specify which device (\$d0||\$d1) should be unlocked"
		return 1

	elif [ "$1" = "d0" ]; then
		serial="$serial_0"
	elif [ "$1" = "d1" ]; then
		serial="$serial_1"
	fi

	screen_res="$(adb -s "$serial" shell dumpsys display | grep deviceWidth \
		| awk -F"deviceWidth=" '{print $2}' | head -n 1)"

	width="$(echo "$screen_res" | cut -d ',' -f1)"
	height="$(echo "$screen_res" | cut -d '=' -f2 | cut -d '}' -f1)"

	# swipe coordinates - from bottom to center
	x=$((width/2))
	y1=$((height-20))
	y2=$((height/2))

	adb_keyevent "$serial" "$KEYCODE_POWER"
	sleep 1
	adb_swipe "$serial" "$x" "$y1" "$x" "$y2"
}

# INIT

# check whether global config file is available
if [ -f ~/.ascent ]; then
	export ASCENT_CONFIG=~/.ascent
fi
# Check whether config file is passed
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
	sanity
	if [ $? -eq 0 ]; then
		# Executing each test-case/suite sequentially.
		for test in "$@"; do
			$test
			# Abort if passed test-case/suite i.e. command, could not be found!
			if [ $? -gt 0 ]; then
				print_help
				log_error "test-case/suite: \"$test\" is not available"
				exit 1
			fi
		done
	fi
else
	# interactive mode (only when sourced or invoked without test-case/suite)
	print_interactive_mode_banner "interactive_mode"
	sanity
fi
