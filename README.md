# heat templates

## Collect cloud parameters
* external net id :
* flavor
* image
* volume type (if needed)
* router id (if needed)

## Create environment parameters files
```
# openstack-heat/floating_ip/heat-parameters-my-env.yaml
# openstack-heat/docker-net/heat-parameters-my-env.yaml
```

## Create floating ip stack
```
# set "external net id" in openstack-heat/floating_ip/heat-parameters-my-env.yaml
```

```
stack=fip-host
env=my-env
eval $( openstack stack output show $stack floating_ip_id -f shell)
if [ -z "$output_value" ]; then
  make build stack_dir=openstack-heat/floating_ip stack_name=$stack heat_parameters=heat-parameters-${env}.yaml
  eval $( openstack stack output show $stack floating_ip_id -f shell)
fi
echo $output_value
floatingip_host_id=$output_value
eval $( openstack stack output show $stack floating_ip_address -f shell)
floatingip_address=$output_value

echo "floating ip : $floatingip_host_id $floatingip_address"

```
## Set Env parameters
```
# set floatingip id address, flavor, image, .... in openstack-heat/docker-net/heat-parameters-my-env.yaml
```

## Create stack
```
# stack_name=my-stack-test
# env=my-env
# time make build stack_dir=openstack-heat/docker-net stack_name=${stack_name} heat_parameters=heat-parameters-${env}.yaml
```
## Delete stack
```
# time make clean stack_dir=openstack-heat/docker-net stack_name=${stack_name} heat_parameters=heat-parameters-${env}.yaml
```
