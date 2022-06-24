#!/usr/bin/env bash

# Set VERSIONS_LIST env variable with last updated versions
fetchVersions() {
  dockerHubUrl="https://hub.docker.com/v2/repositories/library/elasticsearch/tags?ordering=last_updated&page_size=50"
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

tagImages() {
  for majorTag in "${!MAJOR_VERSIONS[@]}"; do
    fullTag=${MAJOR_VERSIONS[$majorTag]}
    echo; docker pull elasticsearch:${fullTag}

    echo "Tagging $fullTag...";
    tagAndPushImage elasticsearch:"${fullTag}" jahia/elasticsearch:"${fullTag}"

    echo "Tagging $fullTag => $majorTag...";
    tagAndPushImage elasticsearch:"${fullTag}" jahia/elasticsearch:"${majorTag}"

    minorTag="$majorTag.$(minorVer "$fullTag")"
    echo "Tagging $fullTag => $minorTag...";
    tagAndPushImage elasticsearch:"${fullTag}" jahia/elasticsearch:"${minorTag}"
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
  docker tag "$1" "$2"
  # docker push "$2"
}

#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+#

# Variable declaration
MIN_VERSION=7.0.0 # ignore any version below this
VERSIONS_LIST=
declare -A MAJOR_VERSIONS=()

# main()
echo; echo "Fetching ES versions..."
fetchVersions
echo; echo "Calculating latest major versions..."
getLatestVersions
echo; echo "Tagging images..."
tagImages
docker images # verify