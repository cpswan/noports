#!/bin/bash

knownHostsFile="$HOME/.ssh/known_hosts"

# Empty the known_hosts file
echo "" >"$knownHostsFile"

if [[ "$(uname)" == "Darwin" ]]; then
    sudo sh -c 'echo "" > /var/root/.ssh/known_hosts'
fi
