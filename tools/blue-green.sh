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

STACK_NETWORK_NAME=${APP}-net
STACK_NETWORK_TEMPLATE=network/heat.yaml
STACK_NETWORK_PARAM=network/param/heat-parameters_${zone}.yaml

STACK_BASTION_NAME=${APP}-bastion
STACK_BASTION_TEMPLATE=bastion/heat.yaml
STACK_BASTION_PARAM=bastion/param/heat-parameters_${zone}.yaml

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
  echo "  front_floating_ip_address: $front_floating_ip_address"

done

#
# network (router,network, subnet)
#
# get param
stack=network
eval $(get_param_stack_color ${stack})
echo "# Check network stack: $stack_infra"
if ! stack_is_present $stack_infra; then
 if create_if_not_exist ; then
   echo "# Create $stack network stack"
   stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone
   stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone
 else
   log_error 1 "ERROR: Stack NET ${stack_infra} absente"
   exit 1
 fi
fi
# get infra id
echo "# Get ${stack_infra} output value"
eval $(get_stack_output_value ${stack_infra} router_id)
echo "  router_id: $router_id"
eval $(get_stack_output_value ${stack_infra} net_id)
echo "  net_id: $net_id"
eval $(get_stack_output_value ${stack_infra} subnet_id)
echo "  subnet_id: $subnet_id"

#
# bastion
#
# get bastion fip
stack=lb
eval $(get_param_stack_color ${stack})
eval $(get_stack_output_value ${stack_fip} bastion_floating_ip_id)
echo "$bastion_floating_ip_id"

stack=bastion
eval $(get_param_stack_color ${stack})
echo "# Check bastion stack: $stack_infra"
if [ -z "$net_id" -o -z "$subnet_id" -o -z "$bastion_floating_ip_id" ] ; then
   log_error 1 "ERROR: parameters stack bastion ${stack_infra} absents"
   exit 1
fi
parameters="front_network=$net_id;front_subnet=$subnet_id;floatingip_id_bastion=$bastion_floating_ip_id"

if ! stack_is_present $stack_infra; then
 if create_if_not_exist ; then
   echo "# Create $stack_infra bastion stack"
   stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

   stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

 else
   log_error 1 "ERROR: Stack bastion ${stack_infra} absente"
   exit 1
 fi
fi
# get bastion id
echo "# Get ${stack_infra} output value"
eval $(get_stack_output_value ${stack_infra} bastion_id)
echo "  bastion_id: $bastion_id"
eval $(get_stack_output_value ${stack_infra} bastion_public_ip_address)
echo "  bastion_public_ip_address: $bastion_public_ip_address"
eval $(get_stack_output_value ${stack_infra} bastion_private_ip_address)
echo "  bastion_private_ip_address: $bastion_private_ip_address"


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

#
# Blue/Green Stack
#
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

# get lb param : bastion ip, front fip id
eval $(get_param_stack_color lb)
eval $(get_stack_output_value ${stack_fip} bastion_floating_ip_address)
echo "bastion_floating_ip_address: $bastion_floating_ip_address"
eval $(get_stack_output_value ${stack_fip} front_floating_ip_id)
lb_front_floating_ip_id=$front_floating_ip_id
echo "lb_front_floating_ip_id: $lb_front_floating_ip_id"

# get blue/green param
eval $(get_param_stack_color ${next_stack_color})
# Get FIP id
eval $(get_stack_output_value ${stack_fip} front_floating_ip_id)
echo "front_floating_ip_id: $front_floating_ip_id"
eval $(get_stack_output_value ${stack_fip} front_floating_ip_address)
echo "front_floating_ip_address: $front_floating_ip_address"
eval $(get_stack_output_value ${stack_volume} data_volume_id)
echo "data_volume_id: $data_volume_id"

if [ -z "$front_floating_ip_id" -o \
     -z "$data_volume_id" -o \
     -z "$bastion_floating_ip_address" ] ; then
   log_error 1 "ERROR: parameters stack ${stack_infra} absents"
   exit 1
fi
parameters="floatingip_id_front=$front_floating_ip_id;data_volume_id=$data_volume_id;ssh_access_cidr=$bastion_floating_ip_address/32"

# create $next_stack_color
if ! stack_is_present $stack_infra ; then
#  stack_recreate $stack_infra
  echo "# Create $stack_infra"
  stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

  stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
else
  if [ ! -z "$STACK_DELETE" ] ; then
    echo "# Recreate $stack_infra"
    stack_validate $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"

    stack_delete $stack_infra
    stack_create $stack_infra $STACK_DIR/$stack_infra_template $STACK_DIR/$stack_infra_param $plateforme $zone \
 "$parameters"
  else
    echo "# Don't touch $stack_infra"
  fi
fi


# wait and test new stack before changing lb (timeout 30s)
#
# TODO: do_test_on_new_stack $stack_infra

#
# LB stack
#
if [ -z "$bastion_floating_ip_address" -o \
     -z "$lb_front_floating_ip_id" -o \
     -z "$front_floating_ip_address" ] ; then
   log_error 1 "ERROR: parameters stack ${STACK_LB_NAME} absents"
   exit 1
fi
parameters="ssh_access_cidr=$bastion_floating_ip_address/32;floatingip_id=$lb_front_floating_ip_id;servers=$front_floating_ip_address;color=$next_stack_color"

# update lb with $next_stack_color
if ! stack_is_present $STACK_LB_NAME ; then
  echo "# Create LB $next_stack_color"
  stack_create_lb $next_stack_color \
   $parameters
else
  echo "# Update LB $next_stack_color"
  stack_update_lb $next_stack_color \
   $parameters
fi

# test new running color stack (timeout 30s)
#
# TODO:
# if ! do_test_on_new_lb ;then
#   echo "# Test on $next_stack_color failed, revert on last color"
#   eval $(get_param_stack_color ${next_stack_color})
#   stack_update_lb $next_stack_color
# else
#   echo "# Test on $next_stack_color success"
# fi

#
get_lb_last_state $STACK_LB_NAME
echo "# LB is $next_stack_color"
