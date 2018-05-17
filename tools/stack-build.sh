#!/bin/bash
# set -e
# set -x
export openstack_cli=${openstack_cli:-openstack}
export heat_template_opt=${heat_template_opt}
export registry_opt=${registry_opt}
export heat_parameters_opt=${heat_parameters_opt}
export stack_name=${1:? stack_name not defined}

${openstack_cli} stack create ${heat_template_opt} ${registry_opt} ${heat_parameters_opt} ${stack_name}
${openstack_cli} stack event list ${stack_name} || true

ret=255; timeout=1200; n=0
until [ $timeout -eq 0 -o $ret -lt 255 ] ; do
  ${openstack_cli} stack event list ${stack_name}
  [ "$?" -gt 0 ] && ret=$?
  eval $(${openstack_cli} stack show ${stack_name} -c stack_status -c stack_status_reason -f shell )
  echo "## $stack_status"
  case "$stack_status" in
   *COMPLETE) ret=0 ;;
   *FAILED) ret=1 ;;
  esac
  echo "WAIT stack ready ?: $timeout s"
  timeout=$(( timeout-1 ))
done

#${openstack_cli} stack event list ${stack_name}

eval $(${openstack_cli} stack show ${stack_name} -c stack_status -c stack_status_reason -f shell )
case "$stack_status" in
  *FAILED) ret=1 ; ${openstack_cli} stack show ${stack_name} -c stack_status -c stack_status_reason -f value ;;
esac

exit $ret
