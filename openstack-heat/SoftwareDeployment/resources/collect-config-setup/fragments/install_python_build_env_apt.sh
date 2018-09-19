#!/bin/bash
set -eux

apt-get -qy update
apt-get -qy install python-pip git gcc python-dev libyaml-dev libssl-dev libffi-dev libxml2-dev libxslt1-dev curl
