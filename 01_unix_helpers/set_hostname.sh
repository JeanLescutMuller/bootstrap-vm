#!/bin/bash -xe
# Sets this VM's name once, for good: /etc/hostname, the name every project keys
# its data by ("Machine name" in bootstrap-home's files/home_AGENTS.md).
# Run as root: bash 01_unix_helpers/set_hostname.sh H-Frank-1
name=${1:?usage: set_hostname.sh NAME (letters, digits, -; e.g. H-Frank-1)}
[[ $name =~ ^[A-Za-z0-9-]+$ ]]

hostnamectl set-hostname "$name"

# cloud-init (preserve_hostname: false by default) may reset it from the provider's metadata at boot
if [ -d /etc/cloud/cloud.cfg.d ]; then
	echo 'preserve_hostname: true' > /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg
fi

[ "$(cat /etc/hostname)" = "$name" ] && [ "$(uname -n)" = "$name" ]
