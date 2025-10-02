#!/usr/bin/env bash

# Nagios plugin to check the furthest expiry date for a FLEXlm feature.
# Returns CRITICAL when the furthest expiry is within the supplied alert window
# or when the feature cannot be inspected.

set -u

LMUTIL=${LMUTIL_PATH:-/usr/local/nagios/libexec/lmutil}

die_unknown() {
    echo "UNKNOWN - $1" >&2
    exit 3
}

print_usage() {
    cat <<USAGE
Usage: $0 [-l /path/to/lmutil] <port> <server> <feature> <alert_days>

Options:
  -l PATH    Override the lmutil binary to execute.
  -h         Show this help message.

Environment variables:
  LMUTIL_PATH  Alternative way to point to lmutil.
USAGE
}

lmutil_path=$LMUTIL

while getopts ":l:h" opt; do
    case "$opt" in
        l)
            lmutil_path=$OPTARG
            ;;
        h)
            print_usage
            exit 3
            ;;
        *)
            die_unknown "invalid option"
            ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -ne 4 ]]; then
    die_unknown "missing arguments"
fi

port=$1
server=$2
feature=$3
alert_days=$4

if ! [[ $alert_days =~ ^[0-9]+$ ]]; then
    die_unknown "alert_days must be a non-negative integer"
fi

alert_threshold=$((alert_days))

if [[ ! -x "$lmutil_path" ]]; then
    die_unknown "lmutil not found or not executable at '$lmutil_path'"
fi

current_epoch=$(date +%s)

run_output=$("$lmutil_path" lmdiag -c "${port}@${server}" "$feature" -n 2>&1)
run_status=$?
if [[ $run_status -ne 0 ]]; then
    die_unknown "lmutil failed: $(echo "$run_output" | tr '\n' ' ')"
fi

mapfile -t dates < <(echo "$run_output" \
    | grep -i 'expiry:' \
    | sed -E 's/.*expiry:[[:space:]]*([0-9]{1,2}-[A-Za-z]{3}-[0-9]{4}).*/\1/i')

if [[ ${#dates[@]} -eq 0 ]]; then
    die_unknown "no expiry dates found for feature '$feature'"
fi

max_epoch=0
max_string=""
for d in "${dates[@]}"; do
    epoch=$(date -d "$d" +%s 2>/dev/null || echo '')
    if [[ -z $epoch ]]; then
        continue
    fi
    if [[ $epoch -gt $max_epoch ]]; then
        max_epoch=$epoch
        max_string=$(date -d "@$epoch" '+%d-%b-%Y')
    fi
done

if [[ $max_epoch -le 0 ]]; then
    die_unknown "unable to parse expiry dates"
fi

seconds_remaining=$(( max_epoch - current_epoch ))
if [[ $seconds_remaining -ge 0 ]]; then
    diff_days=$(( seconds_remaining / 86400 ))
else
    diff_days=$(( (seconds_remaining - 86399) / 86400 ))
fi

if [[ $diff_days -ge $alert_threshold ]]; then
    echo "OK - $feature furthest expiry ($max_string) in $diff_days days"
    exit 0
fi

echo "CRITICAL - $feature furthest expiry ($max_string) in $diff_days days"
exit 2
