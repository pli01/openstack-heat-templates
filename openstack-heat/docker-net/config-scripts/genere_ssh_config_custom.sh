#!/bin/bash
echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -x
# source config from heat
config="$(dirname $0)/install_config_base.cfg"
test -f "$config" && . "$config"
echo "# config $config"

set -x
export deploy_account=$deploy_account
mkdir -p /home/$deploy_account/.ssh
cat << EOF_PRIV > /home/$deploy_account/.ssh/id_rsa
$deploy_private_key
EOF_PRIV
chmod 0600 /home/$deploy_account/.ssh/id_rsa
cat << EOF_PUB > /home/$deploy_account/.ssh/id_rsa.pub
$deploy_public_key
EOF_PUB
chmod 0600 /home/$deploy_account/.ssh/id_rsa.pub
chown -R $deploy_account. /home/$deploy_account/.ssh

