#!/bin/bash
echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -xe -o pipefail
function clean() {
ret=$?
[ "$ret" -gt 0 ] && notify_failure "Deploy $0: $ret"
}
trap clean EXIT QUIT KILL

libdir=/home/debian
[ -f ${libdir}/common_functions.sh ] && source ${libdir}/common_functions.sh

ret=0
# install dependencies
apt-get -q update
apt-get -qy install build-essential python python-dev python-virtualenv supervisor haproxy curl

sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/haproxy

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.ip_nonlocal_bind=1
cat <<EOF > /etc/sysctl.d/100-haproxy.conf
sysctl -w net.ipv4.ip_forward = 1
sysctl -w net.ipv4.ip_nonlocal_bind = 1
EOF

# save haproxy original configuration
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy_base.cfg

# write an initial empty list of worker servers
cat >>/etc/haproxy/servers.json <<EOF
[]
EOF

# write the update script
cat >>/etc/haproxy/update.py <<EOF
import sys
import json
import subprocess

# load server list from metadata
metadata = json.loads(sys.stdin.read())
new_servers = json.loads(metadata.get('meta', {}).get('servers', '[]'))
new_color = metadata.get("meta",{}).get("color",{})
if not new_servers:
    sys.exit(1)  # bad metadata

# compare against known list of servers
current_servers = json.loads(open('/etc/haproxy/servers.json').read())
if current_servers == new_servers:
    sys.exit(0)  # no changes

# record updated list of servers
open('/etc/haproxy/servers.json', 'wt').write(json.dumps(new_servers))

# generate a new haproxy config file
f = open('/etc/haproxy/haproxy.cfg', 'wt')
f.write(open('/etc/haproxy/haproxy_base.cfg').read())
f.write("""
frontend http
   bind $vip:80
   default_backend web-servers
backend web-servers
    mode http
    balance roundrobin
    option httpclose
    option forwardfor
""")
for i, server in enumerate(new_servers):
    f.write('    server {3}-{0} {1}:{2}\n'.format(i, server, __port__, new_color))
f.close()

# reload haproxy's configuration
print('Reloading haproxy with servers: ' + ', '.join(new_servers))
subprocess.call(['service', 'haproxy', 'restart'])
EOF

# add a cron job to monitor the metadata and update haproxy
crontab -l >_crontab || true
echo "PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin" >_crontab
echo "* * * * * curl -s http://169.254.169.254/openstack/latest/meta_data.json | python /etc/haproxy/update.py | /usr/bin/logger -t haproxy_update" >>_crontab
crontab <_crontab
rm _crontab
service haproxy stop
service haproxy start
curl -s http://169.254.169.254/openstack/latest/meta_data.json | python /etc/haproxy/update.py | /usr/bin/logger -t haproxy_update

update-rc.d postfix disable
service postfix stop


apt-get -qy install keepalived psmisc
mkdir -p /etc/keepalived
cat > /etc/keepalived/keepalived.conf <<-EOF
vrrp_script chk_haproxy {
   script "/usr/bin/pkill -0 haproxy"     # verify the pid existance
   interval 2                    # check every 2 seconds
   weight 2                      # add 2 points of prio if OK
}
vrrp_instance vrrp_group_1 {
    state $state
    interface eth0
    garp_master_delay 10
    virtual_router_id 1
    priority $priority
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass $password
    }
    virtual_ipaddress {
        $vip
    }
   track_script {
       chk_haproxy
   }
}
EOF

systemctl enable keepalived
systemctl restart keepalived    

# let Heat know that we are done here
[ "$ret" -gt 0 ] && notify_failure "Deploy lb $0: $ret"
exit $ret
