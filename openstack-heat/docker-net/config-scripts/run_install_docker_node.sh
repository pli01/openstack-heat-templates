#!/bin/bash
set -x

export HOME=/home/deploy-user
ansible_install_dir=/home/deploy-user
deploy_script=install_docker_node
cat > ${ansible_install_dir}/run_${deploy_script}.sh <<'EOF'
#!/bin/bash
set -x
echo "# RUNNING: $(dirname $0)/$(basename $0)"

# Extract script name from wrapper script name (suppress run_ from name)
wrapper_script_name=$(dirname $0)/$(basename $0)
script_name=${wrapper_script_name##*run_}

# source config from heat
config="$(dirname $0)/install_config_base.cfg"
test -f "$config" || config=$config_file
test -f "$config" && . "$config"
echo "# config $config"
export HOME=/home/deploy-user

ansible_install_dir=$ansible_install_dir
if [ -z "${ansible_install_dir}" ] ; then
  ansible_install_dir=$(dirname $0)
fi
(
 cd ${ansible_install_dir}

[ -f "${script_name}" ]  || exit 1

export ANSIBLE_CONNECTION=smart
export ANSIBLE_DEPLOY_LIMIT=all
export ANSIBLE_BECOME_FLAGS="-E -H -S -n"
bash -x ${script_name}
)
EOF

[ -f $(dirname $0)/common_functions.sh ] && source $(dirname $0)/common_functions.sh
[ -f ${ansible_install_dir}/common_functions.sh ] && source ${ansible_install_dir}/common_functions.sh
chmod +x ${ansible_install_dir}/run_${deploy_script}.sh
chown deploy-user. -R ${ansible_install_dir}
su - deploy-user -s /bin/bash -c ${ansible_install_dir}/run_${deploy_script}.sh
ret=$?
echo "Deploy ${deploy_script} $ret"
[ "$ret" -gt 0 ] && notify_failure "Deploy ${deploy_script} $ret failed"
exit 0
