#!/usr/bin/env bash
#
# Nagios check for FLEXlm feature availability
# --------------------------------------------
# Runs `lmutil lmdiag` for the requested feature and interprets the output. The
# script validates its arguments and gracefully reports UNKNOWN when lmutil
# cannot be executed.

set -u

LMUTIL_DEFAULT=/usr/local/nagios/libexec/lmutil
lmutil=${LMUTIL_PATH:-$LMUTIL_DEFAULT}

usage() {
    cat <<USAGE
Usage: $(basename "$0") <port> <server> <feature>

  port     FlexNet port number
  server   Licence server hostname
  feature  Feature to inspect
USAGE
}

nagios_exit() {
    local code=$1
    shift
    echo "$*"
    exit "$code"
}

validate_inputs() {
    if [ $# -ne 3 ]; then
        usage
        nagios_exit 3 "UNKNOWN - invalid number of arguments"
    fi

    if [ ! -x "$lmutil" ]; then
        nagios_exit 3 "UNKNOWN - lmutil not found or not executable at '$lmutil'"
    fi
}

check_status() {
    local port=$1 server=$2 feature=$3
    local diag_output

    if ! diag_output=$("$lmutil" lmdiag -c "${port}@${server}" "$feature" -n 2>&1); then
        nagios_exit 3 "UNKNOWN - lmutil lmdiag failed: ${diag_output%%$'\n'*}"
    fi

    if echo "$diag_output" | grep -qi "This license can be checked out"; then
        nagios_exit 0 "OK - $feature can be checked out"
    fi

    if echo "$diag_output" | grep -qi "This license cannot be checked out"; then
        nagios_exit 2 "CRITICAL - $feature cannot be checked out"
    fi

    # We did not find the expected tokens; report UNKNOWN but include context
    local first_line
    first_line=$(echo "$diag_output" | head -n 1)
    nagios_exit 3 "UNKNOWN - unexpected lmdiag output: ${first_line}"
}

validate_inputs "$@"
check_status "$@"
