#!/bin/bash

echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -x
# source config from heat
config="$(dirname $0)/install_config_base.cfg"
test -f "$config" || config=$config_file
test -f "$config" && . "$config"
echo "# config $config"
# genere static /etc/resolv.conf from userdata
#
[ -z "$nameservers" -o -z "$domainname" ] && exit 1
config=/etc/resolv.conf
for i in $nameservers ;do echo "nameserver $i" ;done | tee $config
echo "search $domainname" | tee -a $config
chmod 0644 $config
