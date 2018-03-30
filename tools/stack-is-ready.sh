#!/bin/bash
#set -x
export stack_name=${1:? stack_name not defined}
export openstack_cli=${openstack_cli:-openstack}

set +o pipefail
ret=1 ; timeout=120 ; n=0
echo "# $(basename $0): Check during ${timeout} seconds if ${stack_name} is ready  ?"
server_list=$(${openstack_cli} server list -c Name -f csv --quote=none --name ${stack_name} | awk ' NR > 1 { print $1 } ' 2>&1)

until [ $n -ge $timeout ] || [ $ret -eq 0 ]
do
  for server in $server_list ; do
   ( set +o pipefail && ${openstack_cli} console log show $server 2>&1 |grep -q 'FINISH: INSTANCE CONFIGURED' ) && echo "$server ready" || echo "$server not ready"
  done | grep "not ready" && ret=1 || ret=0
  echo "WAIT: $n $ret"
  n=$(( n+1 ))
done
exit $ret
