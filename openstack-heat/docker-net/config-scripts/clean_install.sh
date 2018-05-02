#!/bin/bash

echo "Zeroing free space"
dd if=/dev/zero of=/root/zero ; rm -rf /root/zero
