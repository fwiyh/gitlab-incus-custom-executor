#!/usr/bin/env bash

# /opt/incus-driver/prepare.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE}" )" >/dev/null 2>&1 && pwd )"
. ${currentDir}/base.sh # Get variables from base.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

start_container () {
    if incus info "$CONTAINER_ID" >/dev/null 2>/dev/null ; then
        echo 'Found old container, deleting'
        incus delete -f "$CONTAINER_ID"
    fi

    # The container image is hardcoded, but you can use
    # the `CI_JOB_IMAGE` predefined variable
    # https://docs.gitlab.com/ci/variables/predefined_variables/
    # which is available under `CUSTOM_ENV_CI_JOB_IMAGE` to allow the
    # user to specify the image. The rest of the script assumes that
    # you are running on an ubuntu image so modifications might be
    # required.
    incus launch $CUSTOM_ENV_CI_JOB_IMAGE $CONTAINER_ID $CUSTOM_ENV_INCUS_LAUNCH_FLAGS

    # Wait for container to start, we are using systemd to check this,
    # for the sake of brevity.
    timeout=60

    # booting instance check
    for i in $(seq 1 "$timeout"); do
        echo "creating count: $i"

        # systemctl state
        if incus list $CONTAINER_ID status=running >/dev/null 2>/dev/null; then
	    echo "launched container."
            break
        fi

	# timeout
        if [ "$i" == "$timeout" ]; then
            echo "Waited for $timeout seconds to start container, exiting.."
            # Inform GitLab Runner that this is a system failure, so it
            # should be retried.
            exit "$SYSTEM_FAILURE_EXIT_CODE"
        fi

        sleep 1s
    done
}

install_dependencies_debian () {
    echo "Begin install dependencies."
    # update
     incus exec "$CONTAINER_ID" -- sh -c "apt update" 
    # curl
     incus exec "$CONTAINER_ID" -- sh -c "apt install -y curl"

    # Install Git LFS, git comes pre installed with ubuntu image.
    # https://github.com/git-lfs/git-lfs/blob/main/INSTALLING.md
    incus exec "$CONTAINER_ID" -- sh -c "curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash"
    incus exec "$CONTAINER_ID" -- sh -c "apt install -y git-lfs"

    # Install gitlab-runner binary since we need for cache/artifacts.
    # incus exec "$CONTAINER_ID" -- sh -c 'curl -L --output /usr/local/bin/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64"'
    # incus exec "$CONTAINER_ID" -- sh -c 'curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash'
    # incus exec "$CONTAINER_ID" -- sh -c "apt install gitlab-runner"
    # incus exec "$CONTAINER_ID" -- sh -c "chmod +x /usr/local/bin/gitlab-runner"
    echo "End install dependencies."
}

echo "Running in $CONTAINER_ID"

start_container

install_dependencies_debian
