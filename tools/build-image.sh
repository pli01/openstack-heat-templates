#!/bin/bash

# openstack stack create
# wait condition
# disk size 10 

instance=${1:? argument 1 instance not defined}

# env
VOLUME_TYPE=${VOLUME_TYPE:? variable VOLUME_TYPE is not defined}
IMAGE_PROPERTY=${IMAGE_PROPERTY:? variable IMAGE_PROPERTY is not defined}

[ -z "$instance" ] && exit 1

timestamp=$(date '+%Y%m%d-%H%M%S')
snapshot_name=${instance}-${timestamp}
volume_name=${instance}-${timestamp}
image_name=${instance}-${timestamp}

openstack server stop $instance

instance_status=""
while [ "$instance_status" != "SHUTOFF"  ]; do
  instance_status=$(openstack server show -f value -c status ${instance})
  echo "Wait instance ${instance} SHUTOFF/$instance_status"
  sleep 2
done

# get volume root
from_volume_id=$(openstack server show $instance -f value -c volumes_attached | awk -F= ' { print $2 } '| sed -e "s/'//g"  )
echo "Get volume_id from '$instance': $from_volume_id"

# create snapshot of volume 
# force car volume in use
echo "Create snapshot of volume '$from_volume_id'"
openstack volume snapshot create --volume $from_volume_id --force ${snapshot_name}

snapshot_status=""
while [ "$snapshot_status" != "available"  ]; do
  snapshot_status=$(openstack volume snapshot show -f value -c status ${snapshot_name} )
  echo "Wait snapshot ${snapshot_name} available/$snapshot_status"
  sleep 2
done
snapshot_id=$(openstack volume snapshot show -c id -f value ${snapshot_name} )
echo "Snapshot '$snapshot_id' created"

# create volume from snapshot
echo "Create new volume from snapshot '$snapshot_id' on '$VOLUME_TYPE'"
openstack volume create --type $VOLUME_TYPE --snapshot $snapshot_id --bootable ${volume_name}

volume_status=""
while [ "$volume_status" != "available"  ]; do
  volume_status=$(openstack volume show -c status -f value  ${volume_name})
  echo "Wait volume ${volume_name} available/$volume_status"
  sleep 2
done
to_volume_id=$(openstack volume show -c id -f value ${volume_name} )
echo "Volume $to_volume_id created"

# create image from new volume
echo "Create new image '${image_name}' from volume $to_volume_id"
openstack image create \
   --min-ram 0 --min-disk 0 --container-format bare --disk-format qcow2 --property ${IMAGE_PROPERTY} \
   --volume ${to_volume_id} ${image_name}

image_id=$(openstack image show -c id -f value ${image_name} )
image_status=""
while [ "$image_status" != "active"  ]; do
  image_status=$(openstack image show -c status -f value  ${image_id})
  echo "Wait image ${image_name} (${image_id}) active/$image_status"
  sleep 2
done
#image_id=$(openstack image show -c id -f value ${image_id} )
openstack image show ${image_id}

# clean
echo "Cleanup volume '${to_volume_id}'"
openstack volume delete $to_volume_id
while openstack volume show -f value -c status  $to_volume_id  ; do
   echo "Wait delete volume $to_volume_id"
   sleep 1
done

echo "Cleanup snapshot '${snapshot_id}'"
openstack volume snapshot delete $snapshot_id
while openstack volume snapshot show -f value -c status  $snapshot_id  ; do
   echo "Wait delete snapshot $snapshot_id"
   sleep 1
done
