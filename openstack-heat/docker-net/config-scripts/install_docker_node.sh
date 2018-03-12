#!/bin/bash

echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -x
# source config from heat
config="$(dirname $0)/install_config_base.cfg"
test -f "$config" || config=$config_file
test -f "$config" && . "$config"
echo "# config $config"
#

export HOME=/root
export DEBIAN_FRONTEND=noninteractive
apt-get -qqy update
apt-get install -qqy git ansible jq
update-ca-certificates --fresh --verbose

export http_proxy
export https_proxy
export no_proxy

ansible_install_dir=$ansible_install_dir
if [ -z "$ansible_install_dir" ] ; then
  ansible_install_dir=$(dirname $0)
fi
[ -d "${ansible_install_dir}" ] || mkdir -p ${ansible_install_dir}
(
cd ${ansible_install_dir}

# get playbook
git clone https://github.com/pli01/ansible-docker-host.git
cd ansible-docker-host || exit 1

# get roles
bash -x build.sh

# get custom environment config
# TODO: use ansible extra-vars file -e @$ansible_env
ansible_env=$ansible_config
if [ -f "$ansible_env" ] ; then
  cp $ansible_env ansible/config/group_vars/docker/100-env
fi

bash -x deploy.sh
)
