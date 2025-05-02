#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

outputDir=$(getOutputDir)
mkdir -p "${outputDir}/daemons"

waitUntilStarted() {
  logInfo "Waiting for daemon $2 to start"
  # $1 is pid, $2 is deviceName, $3 is logFile, $4 is daemon version
  totalSleepTime=0

  while ! grep "Monitor .*monitor started" "$3"; do
    if ! ps -p "$1" >/dev/null; then
      logErrorAndReport "Daemon $2 has exited. Log file follows: "
      cat "$3"
      # Do something knowing the pid exists, i.e. the process with $PID is running
      exit 1
    fi
    sleep 1
    totalSleepTime=$((totalSleepTime + 1))
    if ((totalSleepTime > daemonStartWait)); then
      logErrorAndReport "Daemon $2 has failed to start. Log file follows: "
      cat "$3"
      exit 1
    fi
  done
}

# e.g. `buildDockerDaemon d 4.0.5``
buildDockerDaemon() {
    dockerfilesDir="$(dirname "$0")/../../dockerfiles"
    local type="$1"
    local version="$2"
    
    logInfo "Building container for:      Type: $type, Version: $version"
    
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
          fTag="-t noports-$language:current"
          fBuildArg=""
      else
          # assume "$version" is a release version like "4.0.5" or "5.2.0"
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
      
      local exitCode=$?
      if [[ $exitCode -ne 0 ]]; then
          logErrorAndReport "Error: Docker build failed with exit code $exitCode"
          return $exitCode
      else
          logInfo "Container built successfully"
          return 0
      fi
}

# e.g. `runDockerDaemon "d" "4.0.5" "deviceName" "clientAtSign" "daemonAtSign" "-u -s"
# e.g. `runDockerDaemon "c" "current" "deviceName" "clientAtSign" "daemonAtSign"`
runDockerDaemon() {
    local type="$1"
    local version="$2"
    local deviceName="$3"
    local clientAt="$4"
    local daemonAt="$5"
    local daemonFlags="$6"

    if [[ "$type" == "d" ]]; then
        language="dart"
    elif [[ "$type" == "c" ]]; then
        language="c"
    else
        logErrorAndReport "Error: Unknown type: $type"
        return 1
    fi

    if [[ "$version" == "current" ]]; then
        fTag="noports-$language:current"
    else
        fTag="noports-$language:v$version"
    fi

    logInfo "Starting container for: Type: $type, Version: $version, Flags: $daemonFlags, Device name: $deviceName, Client atSign: $clientAt, Daemon atSign: $daemonAt"

    sudo docker run \
        -d \
        --rm \
        -v "$HOME/.atsign/keys/:/atsign/.atsign/keys/" \
        "$fTag" \
        /bin/bash -c "sudo service ssh start && /usr/local/bin/sshnpd -a $daemonAt -m $clientAt -d $deviceName $daemonFlags -v"
    
    local exitCode=$?
    if [[ $exitCode -ne 0 ]]; then
        logErrorAndReport "Error: Docker run failed with exit code $exitCode"
        return $exitCode
    else
        logInfo "Container started successfully"
        return 0
    fi
}



# For each daemonVersion
# Start two daemons for each typeAndVersion
# 1) with the -u and -s flags set
# 2) with neither of those flags set
for typeAndVersion in $daemonVersions; do
  logInfo "    Starting daemons for commitId $commitId and version $typeAndVersion"

  pathToBinaries=$(getPathToBinariesForTypeAndVersion "$typeAndVersion")

  cBinary="$pathToBinaries/sshnpd"
  fRoot="--root-domain $atDirectoryHost"
  fAtSigns="-m $clientAtSign -a $daemonAtSign"
  extraFlags=""
  if [[ $(versionIsAtLeast "$typeAndVersion" "d:5.3.0") == "true" ]]; then
    apkamApp=$(getApkamAppName)
    apkamDev=$(getApkamDeviceName "daemon" "$commitId")
    keysFile=$(getApkamKeysFile "$daemonAtSign" "$apkamApp" "$apkamDev")
    extraFlags="-k $keysFile"
  fi

  deviceName=$(getDeviceNameNoFlags "$commitId" "$typeAndVersion")
  logFile="${outputDir}/daemons/${deviceName}.log"
  logInfo "      Starting daemon version $typeAndVersion with neither the -u nor -s flags"
  commandLine="$cBinary $fRoot $fAtSigns -d ${deviceName} --storage-path ${outputDir}/daemons/${deviceName}.storage -v $extraFlags"
  echo "        --> $commandLine  >& $logFile 2>&1 &"
  $commandLine >"$logFile" 2>&1 &

  waitUntilStarted $! "$deviceName" "$logFile"
  echo

  deviceName=$(getDeviceNameWithFlags "$commitId" "$typeAndVersion")
  logFile="${outputDir}/daemons/${deviceName}.log"
  logInfo "      Starting daemon version $typeAndVersion with the -u and -s flags"
  commandLine="$cBinary $fRoot $fAtSigns -d ${deviceName} --storage-path ${outputDir}/daemons/${deviceName}.storage -v -u -s $extraFlags"
  echo "        --> $commandLine  >& $logFile 2>&1 &"
  $commandLine >"$logFile" 2>&1 &
  waitUntilStarted $! "$deviceName" "$logFile"

  echo
  echo

done