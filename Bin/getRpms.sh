#!/bin/bash
VERSION=1

CURL_CMD="curl -sS -n "

get_full_sg_name() {
  local __sg_name="$1"
  local __full_sg_name=$(${CURL_CMD} "https://gerrit.ericsson.se/a/projects/?p=OSS/com" |sed '1d' |  grep "\"id\":" |grep -o "\"OSS%2F.*%2F${__sg_name}\"")
  if [[ -z "$__full_sg_name" ]]; then
    __full_sg_name=$(${CURL_CMD} "https://gerrit.ericsson.se/a/projects/?p=OSS/" |sed '1d' |  grep "\"id\":" |grep -o "\"OSS%2F.*%2F${__sg_name}\"")
  fi
  if [[ ! -z "$__full_sg_name" ]]; then
    echo "$__full_sg_name" |tr -d '"'
  else 
    echo ''
  fi
}

get_commit_from_tag() {
  local __full_sg_name="$1"
  local __sg_version="$2"
  echo $(${CURL_CMD} "https://gerrit.ericsson.se/a/projects/${__full_sg_name}/tags/${__sg_version}" |sed '1d' |jq -r '.object')
}

get_dockerfile_content() {
  local __full_sg_name="$1"
  local __commit="$2"
  local __dockerfile_full_path="$3"
  echo "$(${CURL_CMD} "https://gerrit.ericsson.se/a/projects/${__full_sg_name}/commits/${__commit}/files/${__dockerfile_full_path}/content" |base64 -d |grep -vE '^[ ]*#')"
}

get_rpms_from_dockerfile() {
  local __dockerfile="$1"
  echo "$(grep -oE 'ERIC[0-9a-zA-Z]+_CXP[0-9]+|EXTR[0-9a-zA-Z]+_CXP[0-9]+' <<<"$__dockerfile" |sort -u)"
}

get_parent_from_dockerfile () {
  local __dockerfile="$1"
  local __found=$(grep -B10 FROM <<<"$__dockerfile" |grep -oiE "ARG +[a-zA-Z0-9_-]+IMAGE_NAME *= *[a-zA-Z0-9_\-]+|ARG +[a-zA-Z0-9_-]+IMAGE_TAG *= *([0-9.-]+|latest)")
  if [[ ! -z "$__found" ]]; then
    echo "$__found" |cut -d'=' -f 2 |paste -d: - -
  else 
    echo ''
  fi
}

download_rpms() {
  local __rpms_file="$1"
  local __rpms_download_dir="$2"
  if [ -s "$__rpms_file" ]; then
    rpms_urls=( $(echo "$iso_rpms_urls" |grep -f "$__rpms_file") )
    for rpm_url in "${rpms_urls[@]}"; do
      my_echo "downloading following rpm: ${rpm_url} to ${__rpms_download_dir} directory.."
      wget -q "$rpm_url" -P "$__rpms_download_dir"
    done
  fi
}

my_echo() {
  #:;
  echo "$*"
}

#
# MAIN
# 

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <cENM Product Set x.y.z> <Image name:version> <rpm download base dir>"
  exit 1
fi

cenm_drop=$1
sg_name_version="$2"
rpms_download_base_dir="$3"

sg_name="$(echo $sg_name_version |cut -d ':' -f1)"
sg_version="$(echo $sg_name_version |cut -d ':' -f2)"

if [ ! -d "$rpms_download_base_dir" ]; then echo "Specified rpms download base dir: <$4> doesn't exist, please make sure it is a valid existing directory"; exit; fi

rpms_download_dir="$rpms_download_base_dir/${sg_name}_${sg_version}"

dir=$(basename $PWD)

cenm_rev=$(echo "$cenm_drop" | rev | cut -d'.' -f 1 | rev)
cenm_rel="${cenm_drop%%.${cenm_rev}}"

iso_version=$(curl -sS "https://ci-portal.seli.wh.rnd.internal.ericsson.com/ENM/content/${cenm_rel}/${cenm_drop}" |grep -oP "(?<=ERICenm_CXP9027091-)[0-9.-]+(?=.iso)" |uniq)

if [[ -z "$iso_version" ]]; then echo "ISO version not found"; exit 1; fi

iso_rpms_urls=$(curl -sS "https://ci-portal.seli.wh.rnd.internal.ericsson.com/api/getMediaArtifactVersionData/mediaArtifact/ERICenm_CXP9027091/version/${iso_version}/"  | jq -r '.content[]|select(.type == "rpm")|.url')

my_echo ======
my_echo sg_name="$sg_name"
my_echo sg_version="$sg_version"
rpms_file="${rpms_download_base_dir}/${sg_name}_${sg_version}_rpms"

full_sg_name=''
if [[ "$sg_name" == *-httpd ]]; then
  my_echo "sidecar httpd image found"
  full_sg_name=$(get_full_sg_name "${sg_name%-httpd}")
else
  full_sg_name=$(get_full_sg_name "$sg_name")
fi
my_echo full_sg_name: "$full_sg_name"

if [[ ! -z "$full_sg_name" ]]; then
  commit=$(get_commit_from_tag "$full_sg_name" "$sg_version")
  my_echo commit="$commit"
  if [[ "$sg_name" == "eric-enm-credm-controller" ]]; then
    dockerfile_path="eric-enm-credm-controller-base%2FDockerfile"
  elif [[ "$sg_name" == "eric-enm-modeldeployservice" ]]; then
    dockerfile_path="docker%2FDockerfile"
  elif [[ "$sg_name" == *-httpd ]]; then
    dockerfile_path="${sg_name}%2FDockerfile"
  else
    dockerfile_path="Dockerfile"
  fi
  my_echo dockerfile_path: "$dockerfile_path"
  dockerfile=$(get_dockerfile_content "$full_sg_name" "$commit" "$dockerfile_path")
  sg_rpms=''
  if [[ ! -z "$dockerfile" ]]; then
    sg_rpms=$(get_rpms_from_dockerfile "$dockerfile")
    my_echo sg_rpms="$sg_rpms"
    if [[ ! -z "$sg_rpms" ]]; then
      echo "$sg_rpms" >"$rpms_file"
    fi
  fi
fi

download_rpms "$rpms_file" "$rpms_download_dir"
