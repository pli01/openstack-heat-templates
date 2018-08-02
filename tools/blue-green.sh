#!/bin/bash
#
# script de deploiement: blue/green
#
set -e

# load lib
[ -f $(dirname $0)/blue-green-lib.sh ] || exit 1
source $(dirname $0)/blue-green-lib.sh

plateforme=$1
[ -z "$plateforme" ] && log_error 1 "ERROR: arg plateforme necessaire"


openstack_args="${openstack_args:-} --insecure "
STACK_DIR="heat-templates"
DRY_RUN="${DRY_RUN:-echo }"
CREATE_IF_NOT_EXIST="${CREATE_IF_NOT_EXIST:-false}"
STACK_DELETE="${STACK_DELETE:-}"

#
# configuration
## TODO: sortir la conf environnementale du script
#
## correspondance plateforme => zone
case $plateforme in
   dev) zone=z1 ; STACK_DELETE="${STACK_DELETE}" ;;
   prod) zone=z3 ; STACK_DELETE="" ;;
   *) echo "plateforme $plateforme inconnue"; exit 1 ;;
esac

APP=myapp
## nom stack , template , parametre
STACK_FIP_LB_NAME=floating-ip
STACK_FIP_LB_TEMPLATE=floating-ip/heat.yaml
STACK_FIP_LB_PARAM=floating-ip/param/heat-parameters_${zone}.yaml

STACK_FIP_BLUE_NAME=floating-ip-blue
STACK_FIP_BLUE_TEMPLATE=floating-ip/heat.yaml
STACK_FIP_BLUE_PARAM=floating-ip/param/heat-parameters_${zone}.yaml

STACK_FIP_GREEN_NAME=floating-ip-green
STACK_FIP_GREEN_TEMPLATE=floating-ip/heat.yaml
STACK_FIP_GREEN_PARAM=floating-ip/param/heat-parameters_${zone}.yaml

STACK_VOLUME_BLUE_NAME=${APP}-data-blue
STACK_VOLUME_BLUE_TEMPLATE=volumes/data_volume.yaml
STACK_VOLUME_BLUE_PARAM=volumes/param/heat-parameters_${zone}.yaml

STACK_VOLUME_GREEN_NAME=${APP}-data-green
STACK_VOLUME_GREEN_TEMPLATE=volumes/data_volume.yaml
STACK_VOLUME_GREEN_PARAM=volumes/param/heat-parameters_${zone}.yaml

STACK_INFRA_BLUE_NAME=${APP}-blue
STACK_INFRA_BLUE_TEMPLATE=infra/${APP}.yml
STACK_INFRA_BLUE_PARAM=infra/param/${APP}-parameters_${zone}-blue.yaml

STACK_INFRA_GREEN_NAME=${APP}-green
STACK_INFRA_GREEN_TEMPLATE=infra/${APP}.yml
STACK_INFRA_GREEN_PARAM=infra/param/${APP}-parameters_${zone}-green.yaml

STACK_LB_NAME=${APP}-lb
STACK_LB_TEMPLATE=lb/heat.yaml
STACK_LB_BLUE_PARAM=lb/param/heat-parameters_${zone}-blue.yaml
STACK_LB_GREEN_PARAM=lb/param/heat-parameters_${zone}-green.yaml

#
# check fip
#
for stack in lb blue green ; do
echo "# Check $stack floating-ip stack"
# get param
eval $(get_param_stack_color ${stack})
unset bastion_floating_ip_id
unset front_floating_ip_id
# check stack
  if ! stack_is_present $stack_fip; then
   if create_if_not_exist ;then 
     echo "# Create $stack floating-ip stack"
     stack_validate $stack_fip $STACK_DIR/$stack_fip_template $STACK_DIR/$stack_fip_param $plateforme $zone
     stack_create $stack_fip $STACK_DIR/$stack_fip_template $STACK_DIR/$stack_fip_param $plateforme $zone
   else
     log_error "1" "ERROR: $stack_fip introuvable"
     exit 1
   fi
  fi
# get bastion fip id et front fip id
## TODO: floatingip_id_bastion != bastion_floating_ip_id
  echo "# Get ${stack_fip} bastion_floating_ip_id , front_floating_ip_id"
  eval $(get_fip_id ${stack_fip})
  echo "  bastion_floating_ip_id: $bastion_floating_ip_id"
  echo "  front_floating_ip_id: $front_floating_ip_id"
  echo "# Get ${stack_fip} bastion_floating_ip_address , front_floating_ip_address"
  eval $(get_fip_ip_address ${stack_fip})
  echo "  bastion_floating_ip_address: $bastion_floating_ip_address"
  echo "  front_floating_ip_address": $front_floating_ip_address""

done

#
# volume
#
for stack in blue green ; do
echo "# Check $stack volume stack"
# get param
eval $(get_param_stack_color ${stack})
unset data_volume_id
  if ! stack_is_present $stack_volume; then
   if create_if_not_exist ;then 
     echo "# Create $stack volume stack"
     stack_validate $stack_volume $STACK_DIR/$stack_volume_template $STACK_DIR/$stack_volume_param $plateforme $zone
     stack_create $stack_volume $STACK_DIR/$stack_volume_template $STACK_DIR/$stack_volume_param $plateforme $zone
   else
     log_error 1 "ERROR: Stack VOLUME ${stack_volume} absente"
     exit 1
   fi
  fi
  # get volume id
  echo "# Get ${stack_volume} data_volume_id "
  eval $(get_volume_id ${stack_volume})
  echo "  data_volume_id: $data_volume_id"
done

#set -x
# default and first time: blue
echo "# Get last color"
next_stack_color=blue
# next time: get last state in metadata lb (blue or green)
if stack_is_present $STACK_LB_NAME ;then
  if is_lb_last_stack_color_blue $STACK_LB_NAME; then 
    next_stack_color=green
  else
    next_stack_color=blue
  fi
fi
echo "# Next color: ${next_stack_color}"

eval $(get_param_stack_color ${next_stack_color})
#set -x
# create $next_stack_color
if ! stack_is_present $stack_infra ; then
#  stack_recreate $stack_infra
  echo "# Create $stack_infra"
  stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone
  stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone
else
  if [ ! -z "$STACK_DELETE" ] ; then
    echo "# Recreate $stack_infra"
    stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone
    stack_delete $stack_infra
    stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone
  else
    echo "# Don't touch $stack_infra"
  fi
fi

# update lb with $next_stack_color
if ! stack_is_present $STACK_LB_NAME ; then
  echo "# Create LB $next_stack_color"
  stack_create_lb $next_stack_color
else
  echo "# Update LB $next_stack_color"
  stack_update_lb $next_stack_color
fi

get_lb_last_state $STACK_LB_NAME
echo "# LB is $next_stack_color"
