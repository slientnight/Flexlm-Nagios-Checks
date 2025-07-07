#!/usr/bin/env bash
rlm=/home/slient/rlmutil
port=$1
server=$2
isv=$3
get_diag(){
DIAG_STATUS=`$rlm rlmstat -a -i ${isv} -c ${port}@${server} | grep -oh "server status on"`
if [[ "$DIAG_STATUS" == "server status on" ]]; then
    echo "OK - $isv can be checked out"
     exit 0
else
    echo "Critical - $isv can't be checked out"
     exit 2
fi
}
get_diag

