#!/bin/bash
set -eux

pip install -I os-collect-config os-apply-config os-refresh-config dib-utils heat-cfntools

cfn-create-aws-symlinks
