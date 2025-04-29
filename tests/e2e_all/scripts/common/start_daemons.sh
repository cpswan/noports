#!/bin/bash

# TEMPORARY ----
defaultDaemonVersions="d:4.0.5 d:5.2.0 d:5.5.0 d:current c:current"
defaultClientVersions="d:4.0.5 d:5.2.0 d:5.5.0 d:current"

daemonVersions=$defaultDaemonVersions
clientVersions=$defaultClientVersions
commitId="$(git rev-parse --short HEAD)"
testScriptsDir=/home/jeremy/GitHub/noports/tests/e2e_all/scripts
remoteUsername="atsign"
source "$testScriptsDir/common/common_functions.include.sh"
# END TEMPORARY ----

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

# TEMPORARILY COMMENTING
# source "$testScriptsDir/common/check_env.include.sh" || exit $?

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

# Example usage:
# buildDaemonDockerImage "../../dockerfiles/Dockerfile.dart.release" "noports-dart:v4.0.5" "release=v4.0.5"
buildDaemonDockerImage() {
  local type="$1"
  local version="$2"
  local dockerfilesDir="$(dirname "$0")/../../dockerfiles"
  
  echo "Building docker image for: Type: $type, Version: $version"
  
  if [[ "$type" == "d" || "$type" == "c" ]]; then
    local language=""
    if [[ "$type" == "d" ]]; then
      language="dart"
    else
      language="c"
    fi

    local dockerfile=""
    local tagName=""
    local buildArg=""

    if [[ "$version" == "current" ]]; then
      dockerfile="$dockerfilesDir/Dockerfile.$language.current"
      tagName="noports-$language:current"
    else
      dockerfile="$dockerfilesDir/Dockerfile.$language.release"
      tagName="noports-$language:v$version" 
      buildArg="release=v$version"
    fi
    
    echo "Using: $dockerfile with tag: $tagName"
    
    local buildCommand=(sudo docker build --file "$dockerfile" --tag "$tagName" --quiet --target runtime)
    
    if [[ -n "$buildArg" ]]; then
      buildCommand+=(--build-arg "$buildArg")
    fi
    
    "${buildCommand[@]}" .
    
    local exitCode=$?
    if [[ $exitCode -ne 0 ]]; then
      echo "Error: Docker build failed with exit code $exitCode"
    else
      echo "Docker image built successfully: $tagName"
    fi
    
    return $exitCode
  else
    echo "Error: Unknown type: $type"
    return 1
  fi
}

# Example usage:
# checkAndBuildDockerImage "d" "current"
# checkAndBuildDockerImage "c" "4.0.5"
checkAndBuildDockerImage() {
  local type="$1"
  local version="$2"
  
  if [[ "$type" == "d" || "$type" == "c" ]]; then
    if [[ "$type" == "d" ]]; then
      language="dart"
    elif [[ "$type" == "c" ]]; then
      language="c"
    fi

    if [[ "$version" == "current" ]]; then
      tagName="noports-$language:current"
      echo "Always building current version: $tagName"
      buildDocker=true
    else
      tagName="noports-$language:v$version"
      
      if sudo docker image inspect "$tagName" &>/dev/null; then
        echo "Docker image $tagName already exists, skipping build"
        buildDocker=false
      else
        echo "Docker image $tagName does not exist, will build"
        buildDocker=true
      fi
    fi

    if [[ "$buildDocker" == true ]]; then
      buildDaemonDockerImage "$type" "$version"
      
      local exitCode=$?
      if [[ $exitCode -ne 0 ]]; then
        echo "Error: Docker build failed with exit code $exitCode"
        return $exitCode
      else
        echo "Docker build completed successfully for Type: $type, Version: $version"
        return 0
      fi
    fi
    
    return 0
  else
    echo "Error: Unknown type: $type"
    return 1
  fi
}

# Example usage:
# runDockerDaemon "d" "current" "dart" "@deviceName" "@clientAtSign" "@daemonAtSign" "-s" "noports-dart:current"
runDockerDaemon() {
  local type="$1"
  local version="$2"
  local language="$3"
  local deviceName="$4"
  local clientAt="$5"
  local daemonAt="$6"
  local flags="$7"
  local tagName="$8"
  
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
    "$tagName" \
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

# Check if Docker image exists. If DNE, build Docker image
# for typeAndVersion in $daemonVersions; do
#   type=$(echo "$typeAndVersion" | cut -d':' -f1)
#   version=$(echo "$typeAndVersion" | cut -d':' -f2)
  
#   checkAndBuildDockerImage "$type" "$version"
#   if [[ $? -ne 0 ]]; then
#     exit 1
#   fi
# done

# Run Docker containers
for typeAndVersion in $daemonVersions; do
  type=$(echo "$typeAndVersion" | cut -d':' -f1)
  version=$(echo "$typeAndVersion" | cut -d':' -f2)

  if [[ "$type" == "d" || "$type" == "c" ]]; then
    if [[ "$type" == "d" ]]; then
      language="dart"
    elif [[ "$type" == "c" ]]; then
      language="c"
    fi

    if [[ "$version" == "current" ]]; then
      tagName="noports-$language:current"
    else
      tagName="noports-$language:v$version"
    fi

    deviceName=$(getDeviceNameWithFlags "$commitId" "$typeAndVersion")
    runDockerDaemon "$type" "$version" "$language" "$deviceName" "$clientAtSign" "$daemonAtSign" "-s" "$tagName"
    
    if [[ $? -ne 0 ]]; then
      exit $?
    fi

    deviceName=$(getDeviceNameNoFlags "$commitId" "$typeAndVersion")
    runDockerDaemon "$type" "$version" "$language" "$deviceName" "$clientAtSign" "$daemonAtSign" "" "$tagName"
    
    if [[ $? -ne 0 ]]; then
      exit $?
    fi
  else
    echo "Error: Unknown type: $type"
    exit 1
  fi
done
