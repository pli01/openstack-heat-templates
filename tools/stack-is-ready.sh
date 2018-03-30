#!/bin/bash
set +x
export stack_name=${1:? stack_name not defined}
export openstack_cli=${openstack_cli:-openstack}

set +o pipefail
ret=false ; timeout=50 ; n=0
echo "# $(basename $0): Check during ${timeout} seconds if ${stack_name} is ready  ?"
while ! $ret ; do
  ${openstack_cli} server list -c Name -f csv --quote=none --name ${stack_name} | awk ' NR > 1 { print $1 } ' | while read a ; do
   ( set +o pipefail && ${openstack_cli} console log show $a 2>&1 |grep -q 'FINISH: INSTANCE CONFIGURED' ) && echo "$a ready" || echo "$a not ready"
   done | grep "not ready" && ret=false || ret=true
   echo "WAIT: $n $ret"
   n=$(( n+1 ))
   if [ $n -eq $timeout ] ;then  ret=true ; fi
done
