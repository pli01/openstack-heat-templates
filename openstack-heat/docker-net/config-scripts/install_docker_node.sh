#!/bin/bash
set -ex

echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -x
# source config from heat
config="$(dirname $0)/install_config_base.cfg"
test -f "$config" || config=$config_file
test -f "$config" && . "$config"
echo "# config $config"

# get playbook
URL="$INSTALL_URL_DOCKER"
# URL=https://github.com/pli01/ansible-docker-host/archive/master.tar.gz
dest=ansible-docker-host

[ -z "$URL" ] && exit 1


export HOME=/home/deploy-user
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qqy update
sudo apt-get install -qqy curl git ansible jq
sudo update-ca-certificates --fresh --verbose

export http_proxy
export https_proxy
export no_proxy

curl_args=""
if [ ! -z "$REPOSITORY_USERNAME" -a ! -z "$REPOSITORY_PASSWORD" ]; then
 curl_args="-u $REPOSITORY_USERNAME:$REPOSITORY_PASSWORD"
fi

ansible_install_dir=$ansible_install_dir
if [ -z "${ansible_install_dir}" ] ; then
  ansible_install_dir=$(dirname $0)
fi
[ -d "${ansible_install_dir}" ] || mkdir -p ${ansible_install_dir}
(
cd ${ansible_install_dir}

if [ -d "$dest" ] ; then
  rm -rf "$dest"
fi
if [ ! -d "$dest" ] ; then
  mkdir -p $dest
fi

curl $curl_args -L -k -sSf -o - $URL | tar -zxvf -  --strip=1 -C $dest

cd $dest || exit 1

# get roles
bash -x build.sh

bash -x deploy.sh
)
