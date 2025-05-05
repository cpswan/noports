#!/bin/bash

source "$(dirname "$0")/common_functions.include.sh"

# e.g. "buildDockerDaemon d 4.0.5"
buildDockerDaemon() {
    dockerfilesDir="$(dirname "$0")/../../dockerfiles"
    local type="$1"
    local version="$2"
    
    echo "Building container for:      Type: $type, Version: $version"
    
    if [[ "$type" == "d" || "$type" == "c" ]]; then
        if [[ "$type" == "d" ]]; then
            language="dart"
        elif [[ "$type" == "c" ]]; then
            language="c"
        fi

        if [[ "$version" == "current" ]]; then
            dockerfile="$dockerfilesDir/Dockerfile.$language.current"
            fTag="-t noports-$language:current"
            fBuildArg=""
        else
            dockerfile="$dockerfilesDir/Dockerfile.$language.release"
            fTag="-t noports-$language:v$version"
            fBuildArg="--build-arg release=v$version"
        fi

        sudo docker build \
            -f "$dockerfile" \
            $fTag \
            $fBuildArg \
            --quiet \
            --target runtime \
            .
        
        return $?
    else
        echo "Error: Unknown type: $type"
        return 1
    fi
}

daemonVersions="$1"

if [[ -z "$daemonVersions" ]]; then
    echo "Usage: $0 <daemonVersions>"
    echo "Example: $0 \"d:4.0.5 d:5.2.0 d:5.5.0 d:current c:current\""
    exit 1
fi

if [[ -z "${daemonVersions+x}" ]]; then
    echo "Error: daemonVersions variable is not set."
    exit 1
fi

for typeAndVersion in $daemonVersions; do
    type=$(echo "$typeAndVersion" | cut -d':' -f1)
    version=$(echo "$typeAndVersion" | cut -d':' -f2)
    
    buildDockerDaemon "$type" "$version"
    if [[ $? -ne 0 ]]; then
        echo "Failed to build docker daemon for type: $type, version: $version"
        exit 1
    fi
    echo "Successfully built docker daemon for type: $type, version: $version"
done
