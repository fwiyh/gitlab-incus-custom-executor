#!/usr/bin/env bash

# /opt/incus-driver/cleanup.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE}" )" >/dev/null 2>&1 && pwd )"
. ${currentDir}/base.sh # Get variables from base.

echo "Deleting container $CONTAINER_ID"

incus stop -f "$CONTAINER_ID" 
incus delete -f "$CONTAINER_ID"
