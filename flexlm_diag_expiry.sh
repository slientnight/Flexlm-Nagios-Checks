#!/usr/bin/env bash

lmutil=/usr/local/nagios/libexec/lmutil
port=$1
server=$2
feature=$3
alert_days=$4

# today's date in dd-Mon-YYYY, e.g. “07-Jul-2025”
current_date=$(date +%d-%b-%Y)
current_epoch=$(date -d "$current_date" +%s)

check_expiry() {
    # run diagnostics and capture all 'expiry:' lines
    diag_output=$("$lmutil" lmdiag -c "${port}@${server}" "${feature}" -n 2>/dev/null)
    # extract each date after 'expiry:' (case‐insensitive), e.g. “30-jun-2026”
    mapfile -t dates < <(echo "$diag_output" \
        | grep -i 'expiry:' \
        | sed -E 's/.*expiry:[[:space:]]*([0-9]{1,2}-[A-Za-z]{3}-[0-9]{4}).*/\1/i')

    if [ ${#dates[@]} -eq 0 ]; then
        echo "UNKNOWN - no expiry dates found for feature '$feature'"
        exit 3
    fi

    # convert each to epoch and track max
    max_epoch=0
    for d in "${dates[@]}"; do
        # normalize month to title case so 'date' will parse it
        d_norm=$(echo "$d" | awk '{print tolower($0)}' | sed -E 's/^([0-9]+-[a-z]{3}-[0-9]{4})$/\1/' )
        epoch=$(date -d "$d_norm" +%s 2>/dev/null)
        (( epoch > max_epoch )) && max_epoch=$epoch
    done

    # compute days until that furthest expiry
    diff_days=$(( (max_epoch - current_epoch) / 86400 ))

    # choose OK vs CRITICAL
    if [ "$diff_days" -ge 0 ] && [ "$diff_days" -ge "$alert_days" ]; then
        echo "OK - $feature furthest expiry in $diff_days days"
        exit 0
    else
        echo "CRITICAL - $feature furthest expiry in $diff_days days"
        exit 2
    fi
}

check_expiry

