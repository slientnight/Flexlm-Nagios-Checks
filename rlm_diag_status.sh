#!/usr/bin/env bash
#
# Nagios check for RLM (Reprise License Manager) server health
# ------------------------------------------------------------
# Runs `rlmutil rlmstat` for the requested ISV, validating arguments and
# handling failures gracefully.

set -u

RLMUTIL_DEFAULT=/usr/local/nagios/libexec/rlmutil
rlm=${RLMUTIL_PATH:-$RLMUTIL_DEFAULT}

usage() {
    cat <<USAGE
Usage: $(basename "$0") <port> <server> <isv>

  port    RLM port number
  server  Licence server hostname
  isv     ISV (vendor) name
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

    if [ ! -x "$rlm" ]; then
        nagios_exit 3 "UNKNOWN - rlmutil not found or not executable at '$rlm'"
    fi
}

check_status() {
    local port=$1 server=$2 isv=$3
    local diag_output

    if ! diag_output=$("$rlm" rlmstat -a -i "$isv" -c "${port}@${server}" 2>&1); then
        nagios_exit 3 "UNKNOWN - rlmstat failed: ${diag_output%%$'\n'*}"
    fi

    if echo "$diag_output" | grep -qi "server status on"; then
        nagios_exit 0 "OK - $isv can be checked out"
    fi

    if echo "$diag_output" | grep -qi "server status down"; then
        nagios_exit 2 "CRITICAL - $isv server reported down"
    fi

    local first_line
    first_line=$(echo "$diag_output" | head -n 1)
    nagios_exit 3 "UNKNOWN - unexpected rlmstat output: ${first_line}"
}

validate_inputs "$@"
check_status "$@"
