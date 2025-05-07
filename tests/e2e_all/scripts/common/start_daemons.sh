#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

outputDir=$(getOutputDir)
mkdir -p "${outputDir}/daemons"

waitUntilStarted() {
  local pid="$1"
  local deviceName="$2"
  local logFile="$3"
  local daemonVersion="$4"

  logInfo "Waiting for daemon $deviceName to start"
  # $1 is pid, $2 is deviceName, $3 is logFile, $4 is daemon version
  totalSleepTime=0

  while ! grep "Monitor .*monitor started" "$logFile"; do
    if ! ps -p "$pid" >/dev/null; then
      logErrorAndReport "Daemon $deviceName has exited. Log file follows: "
      cat "$logFile"
      # Do something knowing the pid exists, i.e. the process with $PID is running
      exit 1
    fi
    sleep 1
    totalSleepTime=$((totalSleepTime + 1))
    if ((totalSleepTime > daemonStartWait)); then
      logErrorAndReport "Daemon $2 has failed to start. Log file follows: "
      cat "$logFile"
      exit 1
    fi
  done
}

# e.g. `buildDockerDaemon d 4.0.5``
buildDockerDaemon() {
  dockerfilesDir="$(dirname "$0")/../../dockerfiles"
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
      tag="noports-$language:current"
      fBuildArg=""
  else
      # assume "$version" is a release version like "4.0.5" or "5.2.0"
      dockerfile="$dockerfilesDir/Dockerfile.$language.release"
      tag="noports-$type:v$version"
      fBuildArg="--build-arg release=v$version"
  fi

  logInfo "Building container for:      Type: $type, Version: $version"

  sudo docker build \
      -f "$dockerfile" \
      -t $tag \
      $fBuildArg \
      --quiet \
      --target runtime \
      .
  
  local exitCode=$?
  if [[ $exitCode -ne 0 ]]; then
      logErrorAndReport "Error: Docker build failed with exit code $exitCode"
      return $exitCode
  else
      logInfo "Container built successfully"
      return 0
  fi
}


# usage: `waitUntilDockerDaemonStarted $containerId $timeout`
# Blocking function call until the Docker daemon log's says "monitor started" using `sudo docker logs <containerId`
# $timeout is optional argument, defaults to 30 seconds, specifies the maximum time to wait for the daemon to start
# e.g. `waitUntilDockerDaemonStarted "3f266a8995fb"`
# e.g. `waitUntilDockerDaemonStarted "3f266a8995fb" 30`
waitUntilDockerDaemonStarted() {
  containerId="$1"
  timeoutSeconds="${2:-30}" # second argument is optional, defaults to 30 seconds
  # TODO
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

  if [[ $(versionIsAtLeast "$typeAndVersion" "d:5.3.0") == "true" ]]; then
    apkamApp=$(getApkamAppName)
    apkamDev=$(getApkamDeviceName "daemon" "$commitId")
    # keysFile=$(getApkamKeysFile "$daemonAtSign" "$apkamApp" "$apkamDev")

    # the keys file is in the docker daemon
    # e.g. /atsign/.atsign/keys/@12alpaca.e2e_all.client_2064e58.atKeys
    keysFile="/atsign/.atsign/keys/$daemonAtSign.$apkamApp.$apkamDev".atKeys
    extraFlags="-k $keysFile"
  fi

  deviceName1=$(getDeviceNameWithFlags "$commitId" "$typeAndVersion")
  logFile1="${outputDir}/daemons/${deviceName1}.log"
  echo "Starting daemon version $typeAndVersion with the -u and -s flags"  >> "$logFile"
  runDockerDaemon "$type" "$version" "$deviceName1" "$clientAtSign" "$daemonAtSign" "$extraFlags -s -u"
  sudo docker logs -f "$deviceName1" >> "$logFile1" 2>&1 &

  deviceName2=$(getDeviceNameNoFlags "$commitId" "$typeAndVersion")
  logFile2="${outputDir}/daemons/${deviceName2}.log"
  echo "Starting daemon version $typeAndVersion with neither the -u nor -s flags" >> "$logFile"
  runDockerDaemon "$type" "$version" "$deviceName2" "$clientAtSign" "$daemonAtSign" "$extraFlags"
  sudo docker logs -f "$deviceName2" >> "$logFile2" 2>&1 &
done

# For each daemonVersion
# Start two daemons for each typeAndVersion
# 1) with the -u and -s flags set
# 2) with neither of those flags set
# for typeAndVersion in $daemonVersions; do
#   logInfo "    Starting daemons for commitId $commitId and version $typeAndVersion"

#   pathToBinaries=$(getPathToBinariesForTypeAndVersion "$typeAndVersion")

#   cBinary="$pathToBinaries/sshnpd"
#   fRoot="--root-domain $atDirectoryHost"
#   fAtSigns="-m $clientAtSign -a $daemonAtSign"
#   extraFlags=""
#   if [[ $(versionIsAtLeast "$typeAndVersion" "d:5.3.0") == "true" ]]; then
#     apkamApp=$(getApkamAppName)
#     apkamDev=$(getApkamDeviceName "daemon" "$commitId")
#     keysFile=$(getApkamKeysFile "$daemonAtSign" "$apkamApp" "$apkamDev")
#     extraFlags="-k $keysFile"
#   fi

#   deviceName=$(getDeviceNameNoFlags "$commitId" "$typeAndVersion")
#   logFile="${outputDir}/daemons/${deviceName}.log"
#   logInfo "      Starting daemon version $typeAndVersion with neither the -u nor -s flags"
#   commandLine="$cBinary $fRoot $fAtSigns -d ${deviceName} --storage-path ${outputDir}/daemons/${deviceName}.storage -v $extraFlags"
#   echo "        --> $commandLine  >& $logFile 2>&1 &"
#   $commandLine >"$logFile" 2>&1 &

#   waitUntilStarted $! "$deviceName" "$logFile"
#   echo

#   deviceName=$(getDeviceNameWithFlags "$commitId" "$typeAndVersion")
#   logFile="${outputDir}/daemons/${deviceName}.log"
#   logInfo "      Starting daemon version $typeAndVersion with the -u and -s flags"
#   commandLine="$cBinary $fRoot $fAtSigns -d ${deviceName} --storage-path ${outputDir}/daemons/${deviceName}.storage -v -u -s $extraFlags"
#   echo "        --> $commandLine  >& $logFile 2>&1 &"
#   $commandLine >"$logFile" 2>&1 &
#   waitUntilStarted $! "$deviceName" "$logFile"

#   echo
#   echo

# done