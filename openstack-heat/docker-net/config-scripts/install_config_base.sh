#!/bin/bash
echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -x
# source config from heat
config="$(dirname $0)/$(basename $0 .sh).cfg"
test -f "$config" && . "$config"
echo "# config $config"

export http_proxy=$http_proxy
export https_proxy=$http_proxy

# OS Specific
if [ -f /etc/debian_version ] ; then
  apt-get -qqy update
  # apt-get -qqy upgrade
  apt-get -y install apt-transport-https curl

  # WARNING: FORCE FSCK
  echo "FSCKFIX=yes" | tee -a /etc/default/rcS
  touch /forcefsck

else
  # distrib, version
  distrib=$(awk  -F. ' { print $1 } ' /etc/redhat-release |awk ' /CentOS/ { d="centos"; v=$NF }  /Red Hat/ { d="rhel"; v=$NF } END { print  d v }')
  
  # SELINUX=disabled
  sed -i -e 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux
  sed -i -e 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
  echo "0" > /selinux/enforce
  
  # IPV6=disabled
  grep "^NETWORKING_IPV6=" /etc/sysconfig/network || { echo  "NETWORKING_IPV6=no" >> /etc/sysconfig/network ; } && sed -i.back -e 's/^NETWORKING_IPV6=.*/NETWORKING_IPV6=no/g' /etc/sysconfig/network
  grep "^IPV6INIT=" /etc/sysconfig/network || { echo  "IPV6INIT=no" >> /etc/sysconfig/network ; } && sed -i.back -e 's/^IPV6INIT=.*/IPV6INIT=no/g' /etc/sysconfig/network
  #
  echo "proxy=$http_proxy" >> /etc/yum.conf
  sed -i.back -e 's/^plugins=.*/plugins=0/g' /etc/yum.conf
  #
  # Force preserve hostname on centos/redhat during reboot
  ( echo "preserve_hostname: true" ; cat /etc/cloud/cloud.cfg ) > /etc/cloud/cloud.cfg.new
  cat /etc/cloud/cloud.cfg.new >  /etc/cloud/cloud.cfg
  sed -i.back -e 's/preserve_hostname:.*/preserve_hostname: true/g' /etc/cloud/cloud.cfg
  hostname=$(cat /etc/hostname) ; sed -i.back -e "s/^HOSTNAME=.*/HOSTNAME=$hostname/g" /etc/sysconfig/network
fi

# Common
mkdir -p $env_file_system

# disable ipv6
#echo 'install ipv6 /bin/true' > /etc/modprobe.d/disable_ipv6.conf
sysctl -w net.ipv6.conf.all.disable_ipv6=1 | tee -a /etc/sysctl.conf
sysctl -w net.ipv6.conf.default.disable_ipv6=1 | tee -a /etc/sysctl.conf
sysctl -p
