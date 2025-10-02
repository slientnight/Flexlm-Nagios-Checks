#!/usr/bin/env bash

# Nagios plugin to verify whether a FLEXlm feature can be checked out.
# The plugin expects a port, server, and feature name. Optionally the path to
# lmutil may be overridden through the LMUTIL_PATH environment variable.

set -u

LMUTIL=${LMUTIL_PATH:-/usr/local/nagios/libexec/lmutil}

print_usage() {
    cat <<USAGE
Usage: $0 [-l /path/to/lmutil] <port> <server> <feature>

Options:
  -l PATH    Override the lmutil binary to execute.
  -h         Show this help message.

Environment variables:
  LMUTIL_PATH  Alternative way to point to lmutil.

Returns standard Nagios codes based on whether the feature can be checked out.
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
            echo "UNKNOWN - invalid option" >&2
            print_usage >&2
            exit 3
            ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -ne 3 ]]; then
    echo "UNKNOWN - missing arguments" >&2
    print_usage >&2
    exit 3
fi

port=$1
server=$2
feature=$3

if [[ ! -x "$lmutil_path" ]]; then
    echo "UNKNOWN - lmutil not found or not executable at '$lmutil_path'" >&2
    exit 3
fi

run_output=$("$lmutil_path" lmdiag -c "${port}@${server}" "$feature" -n 2>&1)
run_status=$?

if [[ $run_status -ne 0 ]]; then
    echo "UNKNOWN - lmutil failed: $run_output" | tr '\n' ' '
    exit 3
fi

if echo "$run_output" | grep -q "This license can be checked out"; then
    echo "OK - $feature can be checked out"
    exit 0
fi

if echo "$run_output" | grep -qi "Checkout NOT possible"; then
    echo "CRITICAL - $feature cannot be checked out"
    exit 2
fi

if echo "$run_output" | grep -qi "No such feature"; then
    echo "CRITICAL - feature '$feature' not found"
    exit 2
fi

# If we get here, the output did not match known patterns. Surface it.
first_line=$(echo "$run_output" | head -n 1)
echo "UNKNOWN - unexpected lmdiag output: $first_line" | tr '\n' ' '
exit 3
