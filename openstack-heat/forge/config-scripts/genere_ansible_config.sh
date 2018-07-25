#!/bin/bash

echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -x
# source config from heat
config="$(dirname $0)/install_config_base.cfg"
test -f "$config" || config=$config_file
test -f "$config" && . "$config"
echo "# config $config"

set -x
test -z "$destfile" && exit 1
cat << EOF_CONFIG > $destfile
$ansible_config
EOF_CONFIG
chmod 600 $destfile
