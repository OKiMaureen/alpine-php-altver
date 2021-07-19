#!/usr/bin/env ash
# shellcheck shell=bash

set -eo pipefail

SIGN_NAME="${SIGN_NAME:-signkey-60dd1390}"

script_dir=$(dirname "$0")

. "${script_dir}/utils.sh"

mian()
{
    group "Install abuild"
    apk update
    apk add abuild

    local dir
    find . -type d | while read -r dir
    do
        dir=${dir##*/}
        if [ ! -f "${dir}/phpaltver/x86_64/APKINDEX.tar.gz" ]
        then
            continue
        fi
        group "Regenerating APKINDEX for ${dir}"
        #shellcheck disable=SC2046
        apk index \
            -d phpaltver \
            -o "${dir}/phpaltver/x86_64/APKINDEX.tar.gz" \
            --rewrite-arch x86_64 \
            $(find "${dir}/phpaltver/x86_64" -type f -name "*.apk")
        info "sign the index"
        PACKAGER_PRIVKEY="$(realpath "${SIGN_NAME}".rsa)" abuild-sign "${dir}/phpaltver/x86_64/APKINDEX.tar.gz"
    done
}

mian
