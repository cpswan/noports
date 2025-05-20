#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

outputDir=$(getOutputDir)
mkdir -p "${outputDir}/daemons"

# e.g. `buildDockerDaemon d 4.0.5``
dockerfilesDir="$(dirname "$0")/../../dockerfiles"
cd "$dockerfilesDir"/../../..
buildDockerDaemon() {
  local type="$1"
  local version="$2"
  
  if [[ "$type" == "d" ]]; then
      language="dart"
  elif [[ "$type" == "c" ]]; then
      language="c"
  else
      logErrorAndReport "Error: Unknown type: $type"
      return 1
  fi

  if [[ "$version" == "current" ]]; then
      dockerfile="$dockerfilesDir/Dockerfile.$language.current"
      tag="noports-$type:current"
      fBuildArg=""
      fCache="--no-cache"
  else
      # assume "$version" is a release version like "4.0.5" or "5.2.0"
      dockerfile="$dockerfilesDir/Dockerfile.$language.release"
      tag="noports-$type:v$version"
      fBuildArg="--build-arg release=v$version"
      fCache=""
  fi

  logInfo "Building container for:      Type: $type, Version: $version"

  local dockerBuildCommand="sudo docker build \
      -f \"$dockerfile\" \
      -t $tag \
      --quiet \
      $fCache \
      $fBuildArg \
      --target runtime \
      ."
  
  logInfo "Executing Docker build command: $dockerBuildCommand"

  local max_retries=3
  local retry_count=0
  local exitCode=1

  while [[ $exitCode -ne 0 && $retry_count -lt $max_retries ]]; do
    if [[ $retry_count -gt 0 ]]; then
      logInfo "Retrying Docker build (attempt $((retry_count+1))/$max_retries)..."
      sleep 1
    fi
    
    eval "$dockerBuildCommand"
    exitCode=$?
    retry_count=$((retry_count+1))
  done
  
  if [[ $exitCode -ne 0 ]]; then
      logErrorAndReport "Error: Docker build failed with exit code $exitCode after $max_retries attempts"
      return $exitCode
  else
      logInfo "Container $type $version built successfully"
      return 0
  fi
}

# usage: `waitUntilDockerDaemonStarted $logFile $timeout` 
# - logFile is the path to the log file of the docker daemon
# - timeout is optional, default is 60 seconds
waitUntilDockerDaemonStarted() {
  logFile="$1"
  timeout="${2:-60}"

  for i in $(seq 1 "$timeout"); do
    if grep "monitor started" "$logFile" 2>/dev/null; then
      return 0
    fi
    sleep 0.2
  done

  cat $logFile
  
  exit 1
}

# e.g. `runDockerDaemon "d" "4.0.5" "deviceName" "clientAtSign" "daemonAtSign" "log.txt" "-u -s"
# e.g. `runDockerDaemon "c" "current" "deviceName" "clientAtSign" "daemonAtSign" "log.txt"`
runDockerDaemon() {
  local type="$1"
  local version="$2"
  local deviceName="$3"
  local clientAt="$4"
  local daemonAt="$5"
  local daemonFlags="$6"

  if [[ "$version" == "current" ]]; then
    tag="noports-$type:current"
  else
    tag="noports-$type:v$version"
  fi

  logInfo "Starting container for: Type: $type, Version: $version, Flags: $daemonFlags, Device name: $deviceName, Client atSign: $clientAt, Daemon atSign: $daemonAt"

  containerName="e2e_all-$deviceName"
  local dockerRunCommand="sudo docker run \
    --rm \
    -d \
    --name \"$containerName\" \
    -v \"$testRuntimeDir/keys/:/atsign/.atsign/keys/\" \
    \"$tag\" \
    /bin/bash -c \"sudo service ssh start && /usr/local/bin/sshnpd -a $daemonAt -m $clientAt -d $deviceName $daemonFlags -v\""

  logInfo "Executing: $dockerRunCommand"
  eval "$dockerRunCommand"
}

buildAllDockerDaemons() {
  buildDockerDaemonPids=()
  for typeAndVersion in $daemonVersions; do
    # typeAndVersion is a string like "d:4.0.5" or "c:current"
    type=$(echo "$typeAndVersion" | cut -d: -f1)
    version=$(echo "$typeAndVersion" | cut -d: -f2)
    logInfo "Building docker daemon for type $type and version $version"

    buildDockerDaemon "$type" "$version" &
    buildDockerDaemonPid=$!
    buildDockerDaemonPids+=($buildDockerDaemonPid)
  done

  for pid in "${buildDockerDaemonPids[@]}"; do
    wait $pid
    if [ $? -ne 0 ]; then
      logErrorAndReport "Error: Docker daemon build failed with exit code $?"
      exit 1
    fi
  done
}

runAllDockerDaemons() {
  logFilesToCheck=()
  for typeAndVersion in $daemonVersions; do
    # typeAndVersion is a string like "d:4.0.5" or "c:current"
    type=$(echo "$typeAndVersion" | cut -d: -f1)
    version=$(echo "$typeAndVersion" | cut -d: -f2)

    if [[ $(versionIsAtLeast "$typeAndVersion" "d:5.3.0") == "true" ]]; then
      apkamApp=$(getApkamAppName)
      apkamDev=$(getApkamDeviceName "daemon" "$commitId")
      # keysFile=$(getApkamKeysFile "$daemonAtSign" "$apkamApp" "$apkamDev") # OLD

      # the keys file is in the docker daemon
      # e.g. /atsign/.atsign/keys/@12alpaca.e2e_all.client_2064e58.atKeys
      keysFile="/atsign/.atsign/keys/$daemonAtSign.$apkamApp.$apkamDev".atKeys # NEW
      extraFlags="-k $keysFile"
    else
      extraFlags=""
    fi

    # Run with `-s` and `-u` flags (container 1)
    deviceName1=$(getDeviceNameWithFlags "$commitId" "$typeAndVersion")
    logFile1="${outputDir}/daemons/${deviceName1}.log"
    containerName1="e2e_all-$deviceName1"
    echo "Starting daemon version $typeAndVersion with the -u and -s flags"  >> "$logFile1"
    runDockerDaemon "$type" "$version" "$deviceName1" "$clientAtSign" "$daemonAtSign" "$extraFlags -s -u"
    sudo docker logs -f "$containerName1" >> "$logFile1" 2>&1 &

    # Run without `-s` and `u` flags (container 2)
    deviceName2=$(getDeviceNameNoFlags "$commitId" "$typeAndVersion")
    logFile2="${outputDir}/daemons/${deviceName2}.log"
    containerName2="e2e_all-$deviceName2"
    echo "Starting daemon version $typeAndVersion with neither the -u nor -s flags" >> "$logFile2"
    runDockerDaemon "$type" "$version" "$deviceName2" "$clientAtSign" "$daemonAtSign" "$extraFlags"
    sudo docker logs -f "$containerName2" >> "$logFile2" 2>&1 &

    logFilesToCheck+=("$logFile1")
    logFilesToCheck+=("$logFile2")
  done

  # Wait for all daemons to start
  for logFile in "${logFilesToCheck[@]}"; do
    logInfo "Waiting for Docker daemon with logFile \"$logFile\" to start..."
    waitUntilDockerDaemonStarted "$logFile" 60
  done
}

buildAllDockerDaemons
runAllDockerDaemons
