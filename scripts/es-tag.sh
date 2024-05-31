#!/usr/bin/env bash

# Parameters: 
#  $1 - Fully qualified docker image name e.g. library/elasticsearch

# Do semantic version tagging for elasticsearch/kibana images:
# 1. Fetch last updated versions
# 2. Calculate latest major versions
# 3. Re-tag with semantic versions and push to jahia/ repository

set -eo pipefail
shopt -s inherit_errexit

# Set VERSIONS_LIST env variable with last updated versions
fetchVersions() {
  dockerHubUrl="https://hub.docker.com/v2/repositories/${FULL_IMAGE_NAME}/tags?ordering=last_updated&page_size=50"
  VERSIONS_LIST=$(curl --get -s "${dockerHubUrl}" \
    | jq -r '.results[].name' \
    | sort -Vr)
}

# Populate MAJOR_VERSIONS dictionary
# e.g. $MAJOR_VERSIONS[7] => <latest 7.x.x version>
getLatestVersions() {
    while read -r ver; do
      # check MIN_VERSION threshold
      if [ "$(maxVersion "$ver" "$MIN_VERSION")" == "$ver" ]; then
        majorTag=$(majorVer "$ver")
        currMajorVer="${MAJOR_VERSIONS[$majorTag]}"
        maxVer=$(maxVersion "${ver}" "${currMajorVer}")
        echo "version:${ver}, majorTag:${majorTag}, maxVersion:$maxVer"
        MAJOR_VERSIONS+=( ["$majorTag"]="$maxVer" )
      else
        echo "skipping version:${ver}"
      fi
    done <<< "$VERSIONS_LIST"
}

# Parameters:
# $1 - source image+tag
# $2 - target image+tag to push to remote repository
tagImages() {
  for majorTag in "${!MAJOR_VERSIONS[@]}"; do
    fullTag=${MAJOR_VERSIONS[$majorTag]}
    echo; docker pull ${FULL_IMAGE_NAME}:${fullTag}

    minorTag="$majorTag.$(minorVer "$fullTag")"
    tagAndPushImage "${FULL_IMAGE_NAME}":"${fullTag}" jahia/"${IMAGE_NAME}":"${fullTag}"
    tagAndPushImage "${FULL_IMAGE_NAME}":"${fullTag}" jahia/"${IMAGE_NAME}":"${majorTag}"
    tagAndPushImage "${FULL_IMAGE_NAME}":"${fullTag}" jahia/"${IMAGE_NAME}":"${minorTag}"
  done
}

#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+#

# Helper methods

# compare and return max version between $1 and $2
maxVersion() { echo -e "$1\n$2" | sort -Vr | head -n 1; }
# extract major version e.g. 7.12.4 => 7
majorVer() { echo -e "$1" | awk -F . '{print $1}'; }
# extract minor version e.g. 7.12.4 => 12
minorVer() { echo -e "$1" | awk -F . '{print $2}'; }
tagAndPushImage() {
  echo "Using buildx to tag $1 => $2..."
  if [ "${DRY_RUN}" == "true" ]; then
    echo "Skipping push to docker repository"
  else
    docker buildx imagetools create -t "$2" "$1"
  fi
}

#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+#

# Variable declaration
MIN_VERSION=7.17.4 # ignore any version below this
VERSIONS_LIST=
declare -A MAJOR_VERSIONS=()

FULL_IMAGE_NAME=$1
IMAGE_NAME=$(echo -e "${FULL_IMAGE_NAME}" | awk -F '/' '{print $2}')
if [ -z  "${FULL_IMAGE_NAME}" ] || [ -z "${IMAGE_NAME}" ]; then
  echo "Invalid fully qualified image name: ${FULL_IMAGE_NAME}"
  exit 1
fi

# main()
if [ "${DRY_RUN}" == "true" ]; then
  echo; echo "Running in DRY RUN mode:"
fi
echo; echo "Fetching ${FULL_IMAGE_NAME} versions..."
fetchVersions
echo; echo "Calculating latest major versions..."
getLatestVersions
echo; echo "Tagging images..."
tagImages
echo; docker images # verify
