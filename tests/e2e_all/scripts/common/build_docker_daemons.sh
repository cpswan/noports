#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?


buildAllDockerDaemons() {
  dockerfilesDir="$(dirname "$0")/../../dockerfiles"
  cd "$dockerfilesDir"/../../.. # go to root of the repo

  logInfo "Building all docker daemons for $daemonVersions"
  if [ "${allowParallelization}" = "true" ]; then
    buildDockerDaemonPids=()
    for typeAndVersion in $daemonVersions; do
      # typeAndVersion is a string like "d:4.0.5" or "c:current"
      type=$(echo "$typeAndVersion" | cut -d: -f1)
      version=$(echo "$typeAndVersion" | cut -d: -f2)
      logInfo "Building docker daemon for type $type and version $version"

      buildDockerDaemon "$type" "$version" &
      pid=$!
      buildDockerDaemonPids+=($pid)
    done
    for pid in "${buildDockerDaemonPids[@]}"; do
      wait $pid
    done
  else
    for typeAndVersion in $daemonVersions; do
      # typeAndVersion is a string like "d:4.0.5" or "c:current"
      type=$(echo "$typeAndVersion" | cut -d: -f1)
      version=$(echo "$typeAndVersion" | cut -d: -f2)
      logInfo "Building docker daemon for type $type and version $version"
      buildDockerDaemon "$type" "$version"
    done
  fi
}

buildAllDockerDaemons
