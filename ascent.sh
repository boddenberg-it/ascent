#!/bin/bash

ASCENT_VERSION="0.2"

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
	echo -e "${R}[ERROR] $1 ${NC}\n"
	# "resetting" devices to avoid flaky states
	go_to_homescreen
}

init_test() {
	adb_clear_logcat
	go_to_homescreen
	echo -e "\n${Y}[TEST-$1] $2 ${NC}"
}

test_success() {
	echo -e "${G}[TEST-$1] SUCCESS${NC}\n"
	go_to_homescreen
}

print_help() {

	print_interactive_mode_banner

	help_text="${Y}
There are ${R}two${Y} ways of using ascent.sh

	${R}1st)${Y} ${GRAY}./ascent.sh ${G}arg(s) ${Y}
	${R}2nd)${Y} ${GRAY}source ascent.sh   ${B}(interactive mode) ${Y}

But first, one need to provide a config file, which can
be placed in ~/.ascent or passed when invoking:

	${GRAY}./ascent.sh -c ${G}<path_to_config_file>${Y} ${G}arg(s) ${Y}

Following information need to be provided by config file:

	${GRAY}serial_0=05cd98e0f0fd7bc8 ${Y}
	${GRAY}msisdn_0=1234 ${Y}

	${GRAY}serial_1=4ef2d43176795a51 ${Y}
	${GRAY}msisdn_1=5678 ${Y}

${R}1st)${Y} When ascent.sh is invoked, one can pass several
of following arguments/tests-:

	cases:  ${G}call${Y}, ${G}data${Y}, ${G}internet${Y}, ${G}sms${Y}
	suites: ${G}2g${Y}, ${G}3g${Y}, ${G}4g${Y}, ${G}cs${Y}, ${G}ps${Y}

${R}2nd)${Y} When ascent.sh is sourced, one can use invokations
described in ${R}1st${Y} as well. Additionally one can use
commands, where devices have to be be specified:

	${B}aping ${G}d1 <IP|URL>
	${B}call ${G}d1 d0
	${B}icall ${G}d0 d1${Y} (user accepts/ends call)
	${B}sms  ${G}d0 d1${Y}

Furthermore, ascent provides some handy commands,
when tests failed and devices need to be debugged:

	${B}adb0 ${G}shell input keyevent 66
	${B}adb1 ${Y}(open adb shell of d1)
	${B}go_to_homescreen
	help
	sanity
	unlock_device ${G}(d0||d1)

${Y}More information on https://github.com/boddenberg-it/ascent ${NC}
"
	echo -e "$help_text"
}

print_interactive_mode_banner() {
	header_text="${Y}
Ascent shall help testing cellular networks (2/3/4G) with
two Android devices as subscribers (MS/UE). It provides an
adb-based CLI to test call and SMS functionalities (CS),
as well as data + internet connection (PS).

author:  André Boddenberg (ascent@boddenberg.it)
version: $ASCENT_VERSION ${NC}
"
	echo -e "$header_text"
}

sanity() {

	echo -e "\n${Y}[SANITY_CHECK] does config exist?${NC}"

	if [ ! -f "$ASCENT_CONFIG" ]; then
		echo -e "\n${R}[ERROR] No config file found! Please provide one in ~/.ascent"
		echo -e "        or pass on e.g.:\n"
		echo -e "            ./ascent -c ~/.ascent${NC}\n"
		return 1

	else
		source "$ASCENT_CONFIG"
		cat "$ASCENT_CONFIG"

		missing=""

		if [ -z "${serial_0+x}" ]; then missing="$missing serial_0"; fi
		if [ -z "${msisdn_0+x}" ]; then missing="$missing msisdn_0"; fi

		if [ -z "${serial_1+x}" ]; then missing="$missing serial_1"; fi
		if [ -z "${msisdn_1+x}" ]; then missing="$missing msisdn_1"; fi

		if [ ${#missing} -gt 0 ]; then
			echo -e "${R}[ERROR] Config does not hold following information: $missing${NC}"
			return 1
		else
			echo -e "${G}[SANITY_CHECK] SUCCESS${NC}\n"
		fi
	fi

	echo -e "${Y}[SANITY_CHECK] are both devices connected?${NC}"
	err_codes=0
	adb devices | grep "$serial_0"
	err_codes=$((err_codes+$?))
	adb devices | grep "$serial_1"
	err_codes=$((err_codes+$?))

	if [ "$err_codes" -gt 0 ]; then
		echo -e "${R}[ERROR] not both devices are connected${NC}\n"
		return 1
	else
		echo -e "${G}[SANITY_CHECK] SUCCESS${NC}\n"
	fi
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
	if [ $# -gt 1 ]; then
		serial=$1
		shift
		# maybe this will break!
		adb -s "$serial" wait-for-device shell "$@"
	else
		# interactive mode
		adb -s "$1" wait-for-device shell
	fi
}

adb_keyevent() {
	adb_shell "$1" input keyevent "$2"
}

# Note: SMS Messaging (AOSP) app is required!
adb_send_sms(){
	adb_shell "$1" am start -a android.intent.action.SENDTO \
		-d sms:"$2" --es sms_body "intent_text" --ez exit_on_sent true

	sleep 0.2
	adb_input_text "$1" "input_text"
	sleep 0.2
	adb_keyevent "$1" "$KEYCODE_DPAD_RIGHT"
	sleep 0.2
	adb_keyevent "$1" "$KEYCODE_ENTER"
}

adb_input_text() {
	adb_shell "$1" input text "$2"
}

adb_call() {
	adb_shell "$1" am start -a android.intent.action.CALL -d tel:"$2"
}

adb_ping() {

	ping_count=3
	if [ ! -z "${3+x}" ]; then ping_count="$3"; fi
	# freaky string, because two commands can only be passed to adb shell at
	# once within single quotes, but passing URL and ping count is necessary.
  adb_shell "$1" 'ping -c '"$ping_count"' '"$2"'; echo $?' > ~/.ascent_tmp
	head -n -1 ~/.ascent_tmp
	if [[ $(tail -1 < ~/.ascent_tmp) != "0"* ]]; then return 1; fi
}

adb_swipe() {
	adb_shell "$1" input swipe "$2" "$3" "$4" "$5"
}

adb_clear_logcat() {
		# TODO: introduce d0 d1
		if [ $# -eq 1 ]; then
    	adb -s "$1" wait-for-device logcat -c
		else
			adb -s "$serial_0"  wait-for-device logcat -c
			adb -s "$serial_1" wait-for-device logcat -c
		fi
}

# 0 nothing, 1 gets called, 2 is calling
adb_check_callState() {

	timeout=$(date +%s)

	# default or passed timeout
	if [ "${3+z}" ]; then
		timeout=$((timeout+$3))
	else
		timeout=$((timeout+25))
	fi

	while [ "$(date +%s)" -lt "$timeout" ]; do
		call_state=$(adb_shell "$1" dumpsys telephony.registry | grep "mCallState=$2")
		if [ ${#call_state} -gt 0 ]; then return 0; fi
	done

	return 1
}

adb_grep_logcat() {
	timeout=$(date +%s)

	# default or passed timeout
	if [ "${3+z}" ]; then
		timeout=$((timeout+$3))
	else
		# default timeout of 15 s
		timeout=$((timeout+15))
	fi

	while [ "$(date +%s)" -lt "$timeout" ]; do
		# -d is necessary, because otherwise adb does not terminate on its own.
		adb -s "$1" logcat -d > "logcat_$1.txt"

		# precise amount of matches is passed
		if [ "${4+z}" ]; then
			if [ "$(grep -c "$2" < "logcat_$1.txt")" -eq "$4" ]; then
				rm "logcat_$1.txt"
				return 0;
			fi
		else
			if grep -E "$2" < "logcat_$1.txt" > /dev/null; then
				rm "logcat_$1.txt"
				return 0;
			fi
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
	if adb_grep_logcat "$1" ".*Mms.*onStart:.*mResultCode: -1 = Activity.RESULT_OK" "15" "2" > /dev/null; then
			log_info "$1 successfully sent SMS to CN"
	else
			log_error "TIMEOUT $1 SMS could not be send (yet) $2"
			return 1
	fi

	# verifying that reciever received SMS
	if adb_grep_logcat "$3" "handleSmsReceived" > /dev/null; then
		log_info "$2 received SMS of $1"
	else
		log_error "TIMEOUT SMS of $1 could not be received (yet) $2"
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
		if adb_check_callState "$1" "2" "1" > /dev/null; then
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

	echo -e "${B}[INPUT]${Y} does it ring? (Y|n)${NC}"
	read does_it_ring

	if [ "$does_it_ring" = "n" ]; then
		# canceling call-request in case it's still active
		if adb_check_callState "$1" "2" "1" > /dev/null; then
			adb_keyevent "$1" "$KEYCODE_ENDCALL"
		fi
		log_error "call could not be established"

	else
		log_info "$2 accepts call"
		adb_keyevent "$3" "$KEYCODE_CALL"

		echo -e "${B}[INPUT]${Y} enough of talking? ${NC}"
		read

		log_info "$1 ends call \n"
		adb_keyevent "$1" "$KEYCODE_ENDCALL"
	fi

	go_to_homescreen
}

generic_test() {
	if [ $# -eq 3 ]; then
		if [ "$2" = "d0" ]; then
			"$1" "$serial_0" "$msisdn_1" "$serial_1"
		else
			"$1" "$serial_1" "$msisdn_0" "$serial_0"
		fi
	else
		"$1" "$serial_0" "$msisdn_1" "$serial_1"
		"$1" "$serial_1" "$msisdn_0" "$serial_0"
	fi
}

sms() {
	generic_test "send_sms" "$@"
}

call() {
	generic_test "do_call" "$@"
}

icall() {
	generic_test "do_icall" "$@"
}

data() {
	apn_ip="$(adb1 'ip a | grep global' | cut -d ' ' -f6 | cut -d '.' -f1,2,3)"

	test_ping "$serial_0" "${apn_ip}.1" "3" "DATA"
	test_ping "$serial_1" "${apn_ip}.1" "3" "DATA"
}

internet() {
	test_ping "$serial_0" "8.8.8.8"
	test_ping "$serial_1" "8.8.8.8"
}

aping() {
	if [ "$1" = "d0" ]; then
		test_ping "$serial_0" "$2" "$3"
	else
		test_ping "$serial_1" "$2" "$3"
	fi
}

test_ping() {

	test_name="INTERNET"

	if [ "${4+z}" ]; then
		test_name="$4"
	fi

	init_test "$test_name" "$1 tries to ping $2"

	adb_ping "$@"

	if [ $? -eq 0 ]; then
		test_success "DATA"
	else
		log_error "FAILURE"
	fi
}

cs() {
	sms
	call
}

ps() {
	data
	internet
}

2g() {
	cs
}

3g() {
	cs
	ps
}

4g() {
	3g
}

# INTERACTIVE MODE functions
help() {
	print_help
}

adb0() {
	adb_shell "$serial_0" "$@"
}

adb1() {
	adb_shell "$serial_1" "$@"
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
