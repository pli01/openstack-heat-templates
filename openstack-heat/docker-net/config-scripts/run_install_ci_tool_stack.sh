#!/bin/bash
set -xe
function clean() {
[ "$?" -gt 0 ] && notify_failure "Deploy $0: $?"
}
trap clean EXIT QUIT KILL

export HOME=/home/deploy-user
ansible_install_dir=/home/deploy-user
deploy_script=install_ci_tool_stack

[ -f $(dirname $0)/common_functions.sh ] && source $(dirname $0)/common_functions.sh
[ -f ${ansible_install_dir}/common_functions.sh ] && source ${ansible_install_dir}/common_functions.sh

# genere run_script
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
export ANSIBLE_LOG_PATH=$HOME/${script_name}.log
bash -x ${script_name}
)
EOF

# genere run_systemd
cat > /etc/systemd/system/run_${deploy_script}.service <<EOF
[Unit]
Description="run_${deploy_script}"
After=network.target run_install_docker_node.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${ansible_install_dir}
ExecReload=/bin/su - deploy-user -s /bin/bash -c ${ansible_install_dir}/run_${deploy_script}.sh
ExecStart=/bin/su - deploy-user -s /bin/bash -c ${ansible_install_dir}/run_${deploy_script}.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable run_${deploy_script}
systemctl daemon-reload

chmod +x ${ansible_install_dir}/run_${deploy_script}.sh
chown deploy-user. -R ${ansible_install_dir}
#su - deploy-user -s /bin/bash -c ${ansible_install_dir}/run_${deploy_script}.sh
service run_${deploy_script} start
ret=$?
echo "Deploy ${deploy_script} $ret"
[ "$ret" -gt 0 ] && notify_failure "Deploy ${deploy_script} $ret failed"
[ "$ret" -eq 0 ] && notify_success "Deploy ${deploy_script} $ret success"
