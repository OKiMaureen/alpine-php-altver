#!/usr/bin/env bash

# a bash/ash script for versions
# needs jq curl gzip tar grep

set -eo pipefail

MIRROR_URL=${MIRROR_URL:-https://dl-cdn.alpinelinux.org/alpine}
# this array needs to be descending sorted to build from newest APKBUILD
SUPPORTED_VERSIONS=(edge v3.14 v3.13 v3.12 v3.11 v3.10)
#SUPPORTED_VERSIONS=(edge v3.14 v3.13)
ARCH="${ARCH:-x86_64}"
TMP_DIR="${TMP_DIR:-/tmp}"
BUILD_APK="${BUILD_APK:-build_apk}"

script_dir=$(dirname "$0")

export IN_BUILD_ALL=1
. "${script_dir}/utils.sh"
. "${script_dir}/build.sh"

output_tasks()
{
    echo "::set-output name=$1-$2::$3"
}

build_versions()
{
    local apkbuild_froms=()
    local known_versions=()
    local php7_versions=()
    local php8_versions=()
    cd "${TMP_DIR}"
    local ver; for ver in "${SUPPORTED_VERSIONS[@]}"
    do
        local index_name
        local php8_ver
        local php7_ver
        info "fetch PHP version for alpine ${ver}"
        curl -sfSL "${MIRROR_URL}/${ver}/community/$ARCH/APKINDEX.tar.gz" -o "APKINDEX.tar.gz" || {
            err "failed fetching apkindex for ${ver}"
            continue
        }
        tar xf APKINDEX.tar.gz DESCRIPTION APKINDEX
        index_name=$(cat DESCRIPTION).tar.gz
        mv APKINDEX.tar.gz "${index_name}"
        mv APKINDEX "APKINDEX.${ver}"
        if php8_ver=$(grep -zoPe '\nP:php8\nV:\K[^\n]+' "APKINDEX.${ver}" | grep -oaPe '^\d+\.\d+')
        then
            php8_versions+=("$php8_ver")
            [ "${known_versions[*]}" = "${known_versions[*]%%${php8_ver}*}" ] && {
                known_versions+=("${php8_ver}")
                apkbuild_froms+=("${ver}")
            }
        else
            php8_versions+=("noop")
        fi
        if php7_ver=$(grep -zoPe '\nP:php7\nV:\K[^\n]+' "APKINDEX.${ver}" | grep -oaPe '^\d+\.\d+')
        then
            php7_versions+=("$php7_ver")
            [ "${known_versions[*]}" = "${known_versions[*]%%${php7_ver}*}" ] && {
                known_versions+=("${php7_ver}")
                apkbuild_froms+=("${ver}")
            }
        else
            php7_versions+=("noop")
        fi
    done
    info "found PHP versions \"${known_versions[*]}\""
    info "using APKBUILD from \"${apkbuild_froms[*]}\""
    local i; for i in "${!SUPPORTED_VERSIONS[@]}"
    do
        local alpinever
        local apkbuild_from
        local phpver
        alpinever="${SUPPORTED_VERSIONS[i]}"
        local j; for j in "${!known_versions[@]}"
        do
            local phpver
            local phpmaj
            local commit
            phpver="${known_versions[j]}"
            phpmaj=${phpver%%.*}
            #echo "${php8_versions[i]}" "${php7_versions[i]}" "${phpver}"
            [ "${php8_versions[i]}" = "${phpver}" ] && continue
            [ "${php7_versions[i]}" = "${phpver}" ] && continue
            apkbuild_from="${apkbuild_froms[j]}"
            commit=$(grep -zoPe '\nP:php'"${phpmaj}"'\n(?s:.+?)c:\K[^\n]+' "APKINDEX.${apkbuild_from}" | grep -oaPe '^[a-fA-F0-9]+')
            ${BUILD_APK} "${alpinever}" "${phpmaj}" "${commit}"
        done
    done
}

build_versions
