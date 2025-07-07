#!/usr/bin/env bash
lmutil=/usr/local/nagios/libexec/lmutil
port=$1
server=$2
feature=$3
get_diag(){
DIAG_STATUS=`$lmutil lmdiag -c ${port}@${server} ${feature} -n | grep -m 1 "This license can be checked out"`
if [[ "$DIAG_STATUS" == "This license can be checked out" ]]; then
    echo "OK - $feature can be checked out"
     exit 0
else
    echo "Critical - $feature can't be checked out"
     exit 2
fi    
}
get_diag
