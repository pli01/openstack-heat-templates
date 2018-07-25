#!/bin/bash
echo "# RUNNING: $(dirname $0)/$(basename $0)"
set -x
volume_id="$volume_id"
volume_dev="/dev/disk/by-id/virtio-$(echo ${volume_id} | cut -c -20)"
mkfs.ext4 ${volume_dev}
mkdir -pv /DATA
echo "${volume_dev} /DATA ext4 defaults 1 2" >> /etc/fstab
mount /DATA
