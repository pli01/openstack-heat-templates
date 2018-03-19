#!/bin/bash
set -x

echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -x
# source config from heat
config="$(dirname $0)/install_config_base.cfg"
test -f "$config" || config=$config_file
test -f "$config" && . "$config"
echo "# config $config"

CI_TOOL_STACK_CONF_DIR="$env_file_system/srv/docker/ci-tool-stack"
CI_TOOL_STACK_DOCKER_COMPOSE=${CI_TOOL_STACK_CONF_DIR}/docker-compose.yml

mkdir -p ${CI_TOOL_STACK_CONF_DIR}

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

# prepare config
CI_TOOL_STACK_CONFIG=${CI_TOOL_STACK_CONF_DIR}/ansible-env.yaml
cat > ${CI_TOOL_STACK_CONFIG} <<'EOF'
$CI_TOOL_STACK_CONFIG
EOF

# prepare data dir
mkdir -p /opt/gitlab /opt/nexus-data /opt/jenkins
chown 200 /opt/nexus-data
chown 1000 /opt/jenkins

cd ${CI_TOOL_STACK_CONF_DIR}
echo "$REGISTRY_PASSWORD" | docker login -u $REGISTRY_USERNAME --password-stdin $REGISTRY_URL
docker-compose pull
# docker-compose up -d
#docker logout $REGISTRY_URL

# prepare unit systemd to start docker-compose
cat > /etc/systemd/system/ci-tool-stack.service <<EOF_UNIT
[Unit]
Description=ci-tool-stack Service
After=docker.service
Requires=docker.service

[Service]
Environment="HTTP_PROXY=${http_proxy}"
Environment="HTTPS_PROXY=${https_proxy}"
Environment="NO_PROXY=${no_proxy}"
WorkingDirectory=${CI_TOOL_STACK_CONF_DIR}
Type=oneshot
RemainAfterExit=yes
#Restart=always
#RestartSec=10s
Type=notify
NotifyAccess=all
TimeoutStartSec=120
TimeoutStopSec=30

ExecStartPre=-/usr/local/bin/docker-compose --no-ansi down
ExecStartPre=-/usr/local/bin/docker-compose --no-ansi config -q
ExecStartPre=-/usr/local/bin/docker-compose --no-ansi pull
ExecStartPre=-/usr/local/bin/docker-compose --no-ansi images
ExecStart=/usr/local/bin/docker-compose --no-ansi up -d

ExecStop=/usr/local/bin/docker-compose --no-ansi down

ExecReload=/usr/local/bin/docker-compose --no-ansi pull --parallel
ExecReload=/usr/local/bin/docker-compose --no-ansi up -d

[Install]
WantedBy=multi-user.target
EOF_UNIT

systemctl daemon-reload
systemctl enable ci-tool-stack
