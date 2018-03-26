#!/bin/bash
set -ex

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
apt-get install -qqy curl git ansible jq
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
URL=https://github.com/pli01/ansible-role-service-ci-tool-stack/archive/master.tar.gz
dest=ansible-role-service-ci-tool-stack
if [ ! -d "$dest" ] ; then
   mkdir -p $dest
fi

curl -L -k -sSf -o - $URL | tar -zxvf -  --strip=1 -C $dest

cd $dest || exit 1

# get roles
bash -x build.sh

# get custom environment config
# TODO: use ansible extra-vars file -e @$ansible_env

CI_TOOL_STACK_CONF_DIR=ansible/config/group_vars/ci-tool-stack
CI_TOOL_STACK_DOCKER_COMPOSE=${CI_TOOL_STACK_CONF_DIR}/100-docker-compose

# prepare docker-compose
cat > ${CI_TOOL_STACK_DOCKER_COMPOSE} <<'EOF'
$CI_TOOL_STACK_DOCKER_COMPOSE
EOF
# replace config
sed -i "s|__CI_TOOL_STACK_HOST__|${FRONT_IP_PUBLIC}|g ; \
s|__REGISTRY_URL__|${REGISTRY_URL}|g ; \
s|__http_proxy__|${http_proxy}|g ; \
s|__no_proxy__|${no_proxy}|g ; \
s|__context__|${context}|g ; \
" ${CI_TOOL_STACK_DOCKER_COMPOSE}

# prepare extra config file (service-config)
mkdir -p ansible/files
CI_TOOL_STACK_CONFIG=ansible/files/ansible-env.yaml
cat > ${CI_TOOL_STACK_CONFIG} <<'EOF'
$CI_TOOL_STACK_CONFIG
EOF

# Login
echo "$REGISTRY_PASSWORD" | docker login -u $REGISTRY_USERNAME --password-stdin $REGISTRY_URL

bash -x deploy.sh
)
