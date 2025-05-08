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
  else
      # assume "$version" is a release version like "4.0.5" or "5.2.0"
      dockerfile="$dockerfilesDir/Dockerfile.$language.release"
      tag="noports-$type:v$version"
      fBuildArg="--build-arg release=v$version"
  fi

  logInfo "Building container for:      Type: $type, Version: $version"

  local dockerBuildCommand="sudo docker build \
      -f \"$dockerfile\" \
      -t $tag \
      $fBuildArg \
      --quiet \
      --target runtime \
      ."
  
  logInfo "Executing Docker build command: $dockerBuildCommand"
  eval "$dockerBuildCommand"
  
  local exitCode=$?
  if [[ $exitCode -ne 0 ]]; then
      logErrorAndReport "Error: Docker build failed with exit code $exitCode"
      return $exitCode
  else
      logInfo "Container built successfully"
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
    if grep "Monitor .*monitor started" "$logFile" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  
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

  local dockerRunCommand="sudo docker run \
    --rm \
    -d \
    --name \"$deviceName\" \
    -v \"$testRuntimeDir/apkam/:/atsign/.atsign/keys/\" \
    \"$tag\" \
    /bin/bash -c \"sudo service ssh start && /usr/local/bin/sshnpd -a $daemonAt -m $clientAt -d $deviceName $daemonFlags -v\""

  logInfo "Executing: $dockerRunCommand"
  eval "$dockerRunCommand"
}

for typeAndVersion in $daemonVersions; do
  # typeAndVersion is a string like "d:4.0.5" or "c:current"
  type=$(echo "$typeAndVersion" | cut -d: -f1)
  version=$(echo "$typeAndVersion" | cut -d: -f2)
  logInfo "Building docker daemon for type $type and version $version"

  buildDockerDaemon "$type" "$version"
  if [[ $? -ne 0 ]]; then
    logErrorAndReport "Error: Failed to build docker daemon for type $type and version $version"
    exit 1
  fi
  logInfo "Docker daemon built successfully for type $type and version $version"
done

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
  fi

  # Run with `-s` and `-u` flags
  deviceName1=$(getDeviceNameWithFlags "$commitId" "$typeAndVersion")
  logFile1="${outputDir}/daemons/${deviceName1}.log"
  echo "Starting daemon version $typeAndVersion with the -u and -s flags"  >> "$logFile1"
  runDockerDaemon "$type" "$version" "$deviceName1" "$clientAtSign" "$daemonAtSign" "$extraFlags -s -u"
  docker logs -f "$deviceName1" >> "$logFile1" 2>&1 &
  waitUntilDockerDaemonStarted "$logFile1"
  logInfo "Docker daemon $deviceName1 started successfully. See $logFile1 for details"

  # Run without `-s` and `-u` flags
  deviceName2=$(getDeviceNameNoFlags "$commitId" "$typeAndVersion")
  logFile2="${outputDir}/daemons/${deviceName2}.log"
  echo "Starting daemon version $typeAndVersion with neither the -u nor -s flags" >> "$logFile2"
  runDockerDaemon "$type" "$version" "$deviceName2" "$clientAtSign" "$daemonAtSign" "$extraFlags"
  docker logs -f "$deviceName2" >> "$logFile2" 2>&1 &
  waitUntilDockerDaemonStarted "$logFile2"
  logInfo "Docker daemon $deviceName2 started successfully. See $logFile2 for details"
done
