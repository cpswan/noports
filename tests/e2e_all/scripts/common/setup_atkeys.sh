#!/bin/bash

source "$testScriptsDir/common/common_functions.include.sh"

atKeysDir=$testRuntimeDir/keys
export atKeysDir

mkdir -p $atKeysDir

daemonAtKeysFile="$HOME/.atsign/keys/"$daemonAtSign"_key.atKeys" 
clientAtKeysFile="$HOME/.atsign/keys/"$clientAtSign"_key.atKeys"

cp $daemonAtKeysFile $atKeysDir
logInfo "Copied $daemonAtKeysFile to $atKeysDir"

cp $clientAtKeysFile $atKeysDir
logInfo "Copied $clientAtKeysFile to $atKeysDir"
