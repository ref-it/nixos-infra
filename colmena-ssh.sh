#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
    echo "Usage: ./colmena-ssh.sh [hostname]"
    exit 1
fi

IP=$(nix eval --raw .\#nixosConfigurations.$1.config.deployment.targetHost)

ssh $IP
