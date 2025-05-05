#!/bin/bash

# Example usage: ./run_docker_daemons.sh "@12snowboating" "@12alpaca" "@rv_am" "d:4.0.5 d:5.2.0 d:5.5.0 d:current c:current" "abcdefg"
# To stop all containers: `sudo docker stop $(sudo docker ps -aq)`

source "$(dirname "$0")/common_functions.include.sh"

clientAtSign="$1"
daemonAtSign="$2"
srvAtSign="$3"
daemonVersions="$4"
commitId="$5"

if [[ -z "$clientAtSign" || -z "$daemonAtSign" || -z "$srvAtSign" || -z "$daemonVersions" || -z "$commitId" ]]; then
    echo "Usage: $0 <clientAtSign> <daemonAtSign> <srvAtSign> <daemonVersions> <commitId>"
    exit 1
fi

if [[ -z "${daemonVersions+x}" ]]; then
    echo "Error: daemonVersions variable is not set."
    exit 1
fi

runDockerDaemon() {
    local type="$1"
    local version="$2"
    local language="$3"
    local deviceName="$4"
    local clientAt="$5"
    local daemonAt="$6"
    local flags="$7"
    local fTag="$8"
    
    local flagsDesc=""
    if [[ -n "$flags" ]]; then
        flagsDesc="with $flags flags"
    else
        flagsDesc="with no flags"
    fi
    
    echo "Starting container $flagsDesc, device name: $deviceName"
    
    local containerID=$(sudo docker run \
        -d \
        --rm \
        -v "$HOME/.atsign/keys/:/atsign/.atsign/keys/" \
        "$fTag" \
        /bin/bash -c "sudo service ssh start && echo 'Running container for: Type: $type, Version: $version $flagsDesc' && /usr/local/bin/sshnpd -a $daemonAt -m $clientAt -d $deviceName $flags -v")
    
    local exitCode=$?
    if [[ $exitCode -ne 0 ]]; then
        echo "Error: Docker run failed with exit code $exitCode"
        return $exitCode
    else
        echo "Container $flagsDesc started successfully, ID: $containerID"
        return 0
    fi
}

for typeAndVersion in $daemonVersions; do
    type=$(echo "$typeAndVersion" | cut -d':' -f1)
    version=$(echo "$typeAndVersion" | cut -d':' -f2)

    echo "Running container for:      Type: $type, Version: $version"
    
    if [[ "$type" == "d" || "$type" == "c" ]]; then
        if [[ "$type" == "d" ]]; then
            language="dart"
        elif [[ "$type" == "c" ]]; then
            language="c"
        fi

        if [[ "$version" == "current" ]]; then
            fTag="noports-$language:current"
        else
            fTag="noports-$language:v$version"
        fi

        deviceName=$(getDeviceNameWithFlags "$commitId" "$typeAndVersion")
        runDockerDaemon "$type" "$version" "$language" "$deviceName" "$clientAtSign" "$daemonAtSign" "-s -u" "$fTag"
        
        if [[ $? -ne 0 ]]; then
            exit $?
        fi

        deviceName=$(getDeviceNameNoFlags "$commitId" "$typeAndVersion")
        runDockerDaemon "$type" "$version" "$language" "$deviceName" "$clientAtSign" "$daemonAtSign" "" "$fTag"
        
        if [[ $? -ne 0 ]]; then
            exit $?
        fi
    else
        echo "Error: Unknown type: $type"
        exit 1
    fi
    echo 
    echo
done