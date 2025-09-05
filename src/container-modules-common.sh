#!/bin/sh
# Copyright 2025 Northern.tech AS
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

STATE="$1"
FILES="$2"
TEMP_DIR="$FILES"/tmp

TAR_CMD="tar"

PERSISTENT_STORE="/data/mender-docker-compose"

cleanup() {
    set +e
    if test -f "$PERSISTENT_STORE"/.rw_test; then
        rm -f "$PERSISTENT_STORE"/.rw_test
    fi
}
trap cleanup 1 2 3 6 15

if test -d "$PERSISTENT_STORE"; then
    if touch "$PERSISTENT_STORE"/.rw_test; then
        rm -f "$PERSISTENT_STORE"/.rw_test
    else
        echo "ERROR: cant write to persistent_store in $PERSISTENT_STORE"
        exit 1
    fi
fi

assert_requirements() {
    if ! "$TAR_CMD" --version < /dev/null > /dev/null 2>&1; then
        echo "ERROR: $TAR_CMD is required. Exiting."
        return 1
    fi
    assert_specific_requirements
}

parse_metadata() {
    # $1 -- meta-data JSON file
    # $2 -- header-info JSON file

    application_name=$(jq -r .application_name < "$1")
    platform=$(jq -r .platform < "$1")
    version=$(jq -r .version < "$1")
    artifact_name=$(jq -r .artifact_provides.artifact_name < "$2")

    if test "${application_name}" = ""; then
        echo "ERROR: application_name is required. Exiting."
        return 1
    fi

    if test "${platform}" = ""; then
        echo "ERROR: platform is required. Exiting."
        return 1
    fi

    if test "${version}" = ""; then
        echo "ERROR: version is required. Exiting."
        return 1
    elif test "${version}" != "1"; then
        echo "ERROR: only version 1 is supported, not version ${version}. Exiting."
        return 1
    fi

    if test "${artifact_name}" = ""; then
        echo "ERROR: artifact_name is required. Exiting."
        return 1
    fi
}

handle_artifact() {
    local image_dir
    local image
    local url_new
    local url_current
    local sha_new
    local sha_current
    local rollback_id="last"
    local rc=0

    if test ! -d "$TEMP_DIR"; then
        echo "ERROR: $TEMP_DIR does not exist"
        return 1
    fi

    echo "decompressing images"
    $TAR_CMD -xzf "$1"/images.tar.gz -C "$TEMP_DIR"
    echo "decompressing manifests"
    $TAR_CMD -xzf "$1"/manifests.tar.gz -C "$TEMP_DIR"

    echo "unpacking images"
    for image_dir in "${TEMP_DIR}/images/"*; do
        echo "unpacking $image_dir"
        url_new=$(cat "${image_dir}/url-new.txt")
        url_current=$(cat "${image_dir}/url-current.txt")
        sha_new=$(cat "${image_dir}/sums-new.txt")
        sha_current=$(cat "${image_dir}/sums-current.txt")
        if test "$url_new" = ""; then
            echo "ERROR: payload ${image_dir}/url-new.txt cannot be empty"
            return 1
        fi
        if test "$sha_new" = ""; then
            echo "ERROR: sha_new cannot be empty"
            return 1
        fi

        if test "$url_new" != "$url_current"; then
            if test "$url_current" = ""; then
                echo "ERROR: url_current cannot be empty"
                return 1
            fi
            if test "$sha_current" = ""; then
                echo "ERROR: sha_ccurrent cannot be empty"
                return 1
            fi
        fi
    done
    if test -d "${PERSISTENT_STORE}/${application_name}"; then
        echo "copying existing composition to -previous"
        rm -Rf "${PERSISTENT_STORE}/${application_name}-previous"
        mv -v "${PERSISTENT_STORE}/${application_name}" "${PERSISTENT_STORE}/${application_name}-previous"
    else
        echo "no previous composition found"
    fi
    mkdir -pv "${PERSISTENT_STORE}/${application_name}"/images
    rm -vf "${PERSISTENT_STORE}/${application_name}"/images/*
    for image_dir in "${TEMP_DIR}/images/"*; do
        echo "scanning ${image_dir}"
        url_current=$(cat "${image_dir}/url-current.txt")
        url_new=$(cat "${image_dir}/url-new.txt")
        sha_new=$(cat "${image_dir}/sums-new.txt")
        container_image_load "${url_new}" "${image_dir}/image.img"
        # and the sub module deals with proper image loading
        # we save the image urls and shasums in order to be able to clean up
        echo "${url_new}" >> "${PERSISTENT_STORE}/${application_name}"/images/urls
        echo "${sha_new}" >> "${PERSISTENT_STORE}/${application_name}"/images/shas
    done
    # we should check if the app is healthy and alive, then decide what to do
    # at the moment we assume it is alive and ok
    if test -d "${PERSISTENT_STORE}/${application_name}-previous/manifests"; then
        echo "stopping ${PERSISTENT_STORE}/${application_name}-previous/manifests"
        comp_stop "${application_name}" "${PERSISTENT_STORE}/${application_name}-previous/manifests"
    else
        echo "-previous composition not present; nothing to stop."
    fi
    mv -v "$TEMP_DIR/manifests" "${PERSISTENT_STORE}/${application_name}/"
    echo "starting ${PERSISTENT_STORE}/${application_name}/manifests"
    set +e
    comp_start "${application_name}" "${PERSISTENT_STORE}/${application_name}/manifests" 2>&1
    if test $? -eq 0; then
        echo "successfully started"
        if test -d "${PERSISTENT_STORE}/${application_name}-${rollback_id}"; then
            echo "cleaning up -${rollback_id}"
            clean_up "${PERSISTENT_STORE}/${application_name}-${rollback_id}" # clean up call automatically removes the images in by reference taken from clen-up subdirectory, it relies on the fact that we save them there
            echo "cleaning up -previous"
            clean_up "${PERSISTENT_STORE}/${application_name}-previous" # clean up the composition that was running just now
        else
            echo "successful rollout: nothing to clean"
        fi
        rm -Rfv "${PERSISTENT_STORE}/${application_name}-previous"
        # save_rollback "${PERSISTENT_STORE}/${application_name}-${rollback_id}" # saves the current images ids and manifests as new rollback state. this can be just cp -a "${PERSISTENT_STORE}/${application_name} "${PERSISTENT_STORE}/${application_name}-${rollback_id}"
        echo "saving data for rollback"
        rm -Rfv "${PERSISTENT_STORE}/${application_name}-${rollback_id}"
        cp -va "${PERSISTENT_STORE}/${application_name}" "${PERSISTENT_STORE}/${application_name}-${rollback_id}"
        echo "successfully saved rollback data"
    else
        echo "unsuccessful start"
        rc=8
        clean_up "${PERSISTENT_STORE}/${application_name}"
        comp_rollback "${application_name}" "${PERSISTENT_STORE}/${application_name}/manifests" "${PERSISTENT_STORE}/${application_name}-${rollback_id}"
        if test $? -eq 0; then
            echo "successful rollback"
            rc=80
        else
            echo "unsuccessful rollback trying to start the composition we saw when we started"
            comp_start "${application_name}" "${PERSISTENT_STORE}/${application_name}-previous/manifests"
            if test $? -eq 0; then
                echo "successfully started ${PERSISTENT_STORE}/${application_name}-previous"
                rc=82
            else
                echo "start of ${PERSISTENT_STORE}/${application_name}-previous was unsuccessful; deployment failed; start attempts failed."
                rc=84
            fi
        fi
    fi
    set -e
    return $rc
}

comp_rollback() {
    local -r application_name="$1"
    local -r manifests_dir="$2"
    local -r rollback_dir="$3"

    echo "rolling back ${application_name} to ${roolback_id}"
    comp_stop "${application_name}" "${manifests_dir}" || return 1
    comp_start "${application_name}" "${rollback_dir}"
}

case "$STATE" in
    NeedsArtifactReboot)
        echo "No"
        ;;

    SupportsRollback)
        echo "No" # switch to Yes on MEN-6077
        ;;

    ArtifactInstall)
        parse_metadata "$FILES"/header/meta-data "$FILES"/header/header-info
        assert_requirements
        handle_artifact "$FILES"/files
        ;;

    ArtifactRollback)
        true
        ;;
esac
