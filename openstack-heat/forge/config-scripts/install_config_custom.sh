#!/bin/bash

echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -x
# source config from heat
config="$(dirname $0)/install_config_base.cfg"
test -f "$config" || config=$config_file
test -f "$config" && . "$config"
echo "# config $config"

#
# install custom
#
set -x
# Add Common configs

# Add OS config
if [ -f /etc/debian_version ] ; then
  export DEBIAN_FRONTEND=noninteractive
  export HOME=/root
  apt-get -qqy update
  apt-get install -qqy curl
  update-ca-certificates --fresh --verbose
else
  yum -y update
fi

