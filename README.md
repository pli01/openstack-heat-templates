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
eval $( $openstack stack output show $stack floating_ip -f shell)
if [ -z "$output_value" ]; then
        make build stack_name=$stack stack_dir=openstack-heat/floating_ip heat_parameters=heat-parameters-my-env.yaml
eval $( $openstack stack output show $stack floating_ip -f shell)
fi
echo $output_value
floatingip_host_id=$output_value

echo "floating ip is $floatingip_host_id"

```
## Set Env parameters
```
# set floatingip, flavor, image, .... in openstack-heat/docker-net/heat-parameters-my-env.yaml
```

## Create stack
```
# time make build stack_name=my-test stack_dir=openstack-heat/docker-net heat_parameters=heat-parameters-sample-test.yaml
```
## Delete stack
```
# time make clean stack_name=my-test stack_dir=openstack-heat/docker-net heat_parameters=heat-parameters-sample-test.yaml
```
