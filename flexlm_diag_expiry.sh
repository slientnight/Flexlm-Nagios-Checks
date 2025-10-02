#!/usr/bin/env bash
#
# Nagios check for FLEXlm licence expiry
# --------------------------------------
#   * Validates arguments and dependency (lmutil)
#   * Parses all expiry dates reported by lmdiag and chooses the furthest one
#   * Returns standard Nagios codes (OK/CRITICAL/UNKNOWN)
#
# Usage: flexlm_diag_expiry.sh <port> <server> <feature> <alert_days>
#
# If <alert_days> days or more remain before the furthest expiry date, the check
# returns OK. Otherwise it returns CRITICAL.

set -u

LMUTIL_DEFAULT=/usr/local/nagios/libexec/lmutil
lmutil=${LMUTIL_PATH:-$LMUTIL_DEFAULT}

usage() {
    cat <<USAGE
Usage: $(basename "$0") <port> <server> <feature> <alert_days>

  port        FlexNet port number
  server      Licence server hostname
  feature     Feature to inspect
  alert_days  Minimum number of days remaining before warning
USAGE
}

nagios_exit() {
    local code=$1
    shift
    echo "$*"
    exit "$code"
}

validate_inputs() {
    if [ $# -ne 4 ]; then
        usage
        nagios_exit 3 "UNKNOWN - invalid number of arguments"
    fi

    if [ ! -x "$lmutil" ]; then
        nagios_exit 3 "UNKNOWN - lmutil not found or not executable at '$lmutil'"
    fi

    if ! [[ $4 =~ ^[0-9]+$ ]]; then
        nagios_exit 3 "UNKNOWN - alert_days must be an integer"
    fi
}

check_expiry() {
    local port=$1 server=$2 feature=$3 alert_days=$4

    # Normalise locale so date parsing is deterministic
    local current_date current_epoch
    current_date=$(LC_ALL=C date +%d-%b-%Y)
    current_epoch=$(LC_ALL=C date -d "$current_date" +%s)

    local diag_output
    if ! diag_output=$("$lmutil" lmdiag -c "${port}@${server}" "$feature" -n 2>&1); then
        nagios_exit 3 "UNKNOWN - lmutil lmdiag failed: ${diag_output%%$'\n'*}"
    fi

    mapfile -t expiry_dates < <(echo "$diag_output" \
        | grep -i "expiry:" \
        | sed -E 's/.*expiry:[[:space:]]*([0-9]{1,2}-[A-Za-z]{3}-[0-9]{4}).*/\1/i')

    if [ ${#expiry_dates[@]} -eq 0 ]; then
        nagios_exit 3 "UNKNOWN - no expiry dates found for feature '$feature'"
    fi

    local max_epoch=0 valid_date=false
    for raw_date in "${expiry_dates[@]}"; do
        # Upper case the month so date(1) understands it reliably
        local normalised
        normalised=$(echo "$raw_date" | tr '[:lower:]' '[:upper:]')
        local epoch
        if epoch=$(LC_ALL=C date -d "$normalised" +%s 2>/dev/null); then
            valid_date=true
            if (( epoch > max_epoch )); then
                max_epoch=$epoch
            fi
        fi
    done

    if [ "$valid_date" = false ]; then
        nagios_exit 3 "UNKNOWN - failed to parse expiry dates for '$feature'"
    fi

    local diff_days=$(( (max_epoch - current_epoch) / 86400 ))

    if (( diff_days >= alert_days )); then
        nagios_exit 0 "OK - $feature furthest expiry in $diff_days days"
    elif (( diff_days >= 0 )); then
        nagios_exit 2 "CRITICAL - $feature furthest expiry in $diff_days days"
    else
        nagios_exit 2 "CRITICAL - $feature already expired ($diff_days days ago)"
    fi
}

validate_inputs "$@"
check_expiry "$@"
