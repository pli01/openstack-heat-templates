#!/bin/bash
echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -ex
# source config from heat
config="$(dirname $0)/install_config_base.cfg"
test -f "$config" || config=$config_file
test -f "$config" && . "$config"
echo "# config $config"
#

export DEBIAN_FRONTEND=noninteractive
apt-get -qqy update
apt-get install -qqy git ansible jq
update-ca-certificates --fresh --verbose

export http_proxy
export https_proxy
(
cd $(dirname $0)

git clone https://github.com/pli01/ansible-docker-host.git
cd ansible-docker-host || exit 1
bash -x build.sh
)
