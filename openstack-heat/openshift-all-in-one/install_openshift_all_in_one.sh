#!/bin/bash
set -ex

# Config env
repository_srv="$repository_srv"
http_proxy="$http_proxy"
no_proxy="$no_proxy"
proxy_auth='$proxy_auth'
origin_repo_url="$origin_repo_url"
fip=$fip

ip=$(ip add  |grep inet.*eth0 | awk ' { print $2 }' | awk -F/ ' { print $1 } ')
net=$(ip add  |grep inet.*eth0 | awk ' { print $2 }')
eval $(ipcalc -p -n $net)
# echo $NETWORK/$PREFIX

# SELINUX enabled
cat <<EOF > /etc/selinux/config
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
#SELINUX=disabled
SELINUX=enforcing
# SELINUXTYPE= can take one of three two values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected.
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted
EOF
setenforce Enforcing || true

# install prereq
yum update -y
yum install -y vim git curl jq
yum install -y python-jinja2 pyOpenSSL python-lxml
# enable NetworkManager
yum install -y NetworkManager
systemctl enable NetworkManager

# install tinyproxy
yum install -y tinyproxy
cat <<EOF >> /etc/tinyproxy/tinyproxy.conf
${proxy_auth}
no upstream "${repository_srv}"
no upstream "${fip}"
upstream ${http_proxy}
Allow $NETWORK/$PREFIX
Allow 172.16.0.0/12
EOF
service tinyproxy restart

# configure yum http proxy
sed  -i -e '/^proxy=.*/d' /etc/yum.conf  ; echo "proxy=http://$ip:8888" >> /etc/yum.conf

# Use local http proxy
export http_proxy=http://$ip:8888
export https_proxy=http://$ip:8888
export no_proxy=${no_proxy},169.254.169.254,localhost,${repository_srv},${fip},${ip}

# install ansible 2.4.5
pip install -i http://${repository_srv}/nexus/repository/pypi/simple --trusted-host ${repository_srv} ansible==2.4.5.0

# clone repo
cd /root
#git clone https://github.com/openshift/openshift-ansible
#git checkout release-3.9
#cd openshift-ansible
ops_url=http://github.com/openshift/openshift-ansible/archive/release-3.9.tar.gz
ops_filename=$(basename $ops_url)
ops_dirname=openshift-ansible-$(basename $ops_url .tar.gz)
curl -O -LS $ops_url && \
  tar -zxvf $ops_filename
cd ${ops_dirname}

# configure openshift all in one
cat <<EOF | patch -p1 -b
diff --git a/inventory/hosts.localhost b/inventory/hosts.localhost
index c611fa1..f3a1862 100644
--- a/inventory/hosts.localhost
+++ b/inventory/hosts.localhost
@@ -14,7 +14,17 @@ osm_cluster_network_cidr=10.128.0.0/14
 openshift_portal_net=172.30.0.0/16
 osm_host_subnet_length=9
 # localhost likely doesn't meet the minimum requirements
-openshift_disable_check=disk_availability,memory_availability
+openshift_disable_check=disk_availability,memory_availability,docker_storage,docker_image_availability
+openshift_node_groups=[{'name': 'node-config-all-in-one', 'labels': ['node-role.kubernetes.io/master=true', 'node-role.kubernetes.io/infra=true', 'node-role.kubernetes.io/compute=true']}]
+openshift_http_proxy=${http_proxy}
+
+openshift_https_proxy=${https_proxy}
+openshift_no_proxy='${no_proxy}'
+openshift_enable_excluders=false
+openshift_hostname_check=false
+openshift_release=3.9
+containerized=true
+openshift_public_ip=${fip}

 [masters]
 localhost ansible_connection=local
diff --git a/roles/openshift_repos/templates/CentOS-OpenShift-Origin.repo.j2 b/roles/openshift_repos/templates/CentOS-OpenShift-Origin.repo.j2
index b0c036e..680cdb3 100644
--- a/roles/openshift_repos/templates/CentOS-OpenShift-Origin.repo.j2
+++ b/roles/openshift_repos/templates/CentOS-OpenShift-Origin.repo.j2
@@ -1,6 +1,7 @@
 [centos-openshift-origin]
 name=CentOS OpenShift Origin
-baseurl=http://mirror.centos.org/centos/7/paas/x86_64/openshift-origin/
+#baseurl=http://mirror.centos.org/centos/7/paas/x86_64/openshift-origin/
+baseurl=${origin_repo_url}
 enabled=1
 gpgcheck=1
 gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-PaaS
EOF

## disable ansible 2.5
sed -i -e '/.*ansible$/d'  ./roles/openshift_node/defaults/main.yml

# Prepare installer openshift all in one
cat <<EOD > /root/install_ops.sh
export repository_srv="${repository_srv}"
export http_proxy=${http_proxy}
export https_proxy=${https_proxy}
export no_proxy=${no_proxy}
export fip=${fip}

cd ${ops_dirname}
ansible-playbook -i inventory/hosts.localhost playbooks/prerequisites.yml
ansible-playbook -i inventory/hosts.localhost playbooks/deploy_cluster.yml
EOD

true
if [ "$?" == 0 ] ; then $wc_notify -k --data-binary '{"status": "SUCCESS"}' ; else $wc_notify -k --data-binary '{"status": "FAILURE"}' ; fi
reboot
