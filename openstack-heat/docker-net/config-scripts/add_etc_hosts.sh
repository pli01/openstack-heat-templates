#!/bin/bash
echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -x
# source config from heat
config="$(dirname $0)/install_config_base.cfg"
test -f "$config" && . "$config"
echo "# config $config"

set -x
#
# fake dns genere dns entry
#
echo "#### $context" >> /etc/hosts
for i in $(seq 0  $(($front_node_count-1))) ; do
echo "${front_subnet_prefix}$i ${stack}-$context-front-node-$i";
done | sort -n | tee -a /etc/hosts
for i in $(seq 0  $(($bastion_node_count-1))) ; do
echo "${front_bastion_subnet_prefix}$i ${stack}-$context-bastion-$i";
done | sort -n | tee -a /etc/hosts
