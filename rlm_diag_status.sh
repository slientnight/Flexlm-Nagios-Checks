#!/usr/bin/env bash

# Nagios plugin to verify whether an RLM server is reporting available licenses
# for a given ISV module. It wraps rlmutil rlmstat and parses the output for the
# expected status lines.

set -u

RLMUTIL=${RLMUTIL_PATH:-/usr/local/nagios/libexec/rlmutil}

print_usage() {
    cat <<USAGE
Usage: $0 [-r /path/to/rlmutil] <port> <server> <isv>

Options:
  -r PATH    Override the rlmutil binary to execute.
  -h         Show this help message.

Environment variables:
  RLMUTIL_PATH  Alternative way to point to rlmutil.
USAGE
}

rlmutil_path=$RLMUTIL

while getopts ":r:h" opt; do
    case "$opt" in
        r)
            rlmutil_path=$OPTARG
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
isv=$3

if [[ ! -x "$rlmutil_path" ]]; then
    echo "UNKNOWN - rlmutil not found or not executable at '$rlmutil_path'" >&2
    exit 3
fi

run_output=$("$rlmutil_path" rlmstat -a -i "$isv" -c "${port}@${server}" 2>&1)
run_status=$?

if [[ $run_status -ne 0 ]]; then
    echo "UNKNOWN - rlmutil failed: $run_output" | tr '\n' ' '
    exit 3
fi

if echo "$run_output" | grep -q "server status on"; then
    echo "OK - $isv server status is up"
    exit 0
fi

if echo "$run_output" | grep -qi "server not running"; then
    echo "CRITICAL - $isv server reports not running"
    exit 2
fi

if echo "$run_output" | grep -qi "no licenses in use"; then
    # Server may be up but not granting licenses; treat as warning to highlight.
    echo "WARNING - $isv server up but no licenses in use"
    exit 1
fi

first_line=$(echo "$run_output" | head -n 1)
echo "UNKNOWN - unexpected rlmstat output: $first_line" | tr '\n' ' '
exit 3
