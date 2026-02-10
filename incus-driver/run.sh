#!/usr/bin/env bash

# /opt/incus-driver/run.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE}" )" >/dev/null 2>&1 && pwd )"
. ${currentDir}/base.sh # Get variables from base.

echo "Run Script: ${1}"

incus exec "$CONTAINER_ID" /bin/bash < "${1}"
if [ $? -ne 0 ]; then
    # Exit using the variable, to make the build as failure in GitLab
    # CI.
    exit $BUILD_FAILURE_EXIT_CODE
fi
