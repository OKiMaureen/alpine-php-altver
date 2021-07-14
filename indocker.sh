#!/usr/bin/env ash
# shellcheck shell=bash

set -eo pipefail

SIGN_NAME="${SIGN_NAME:-signkey-60dd1390}"
BUILD_USER="${BUILD_USER:-user}"

script_dir=$(dirname "$0")

. "${script_dir}/utils.sh"
. "${script_dir}/fetch_apkbuild.sh"

prepare()
{
    group "Add build tools"
    apk update --no-progress
    apk add --no-progress \
        alpine-sdk \
        grep \
        coreutils \
        sudo \
        shadow \
        libxml2-dev libgcrypt-dev libgpg-error-dev # for libxslt / ext-xsl

    group "Add build user"
    useradd -G abuild -m "${BUILD_USER}" || :

    group "Add build signature"
    mkdir -p "/home/${BUILD_USER}/.abuild"
    [ -f "/home/${BUILD_USER}/.abuild/${SIGN_NAME}.rsa" ] ||
        cp "${script_dir}"/sign.rsa "/home/${BUILD_USER}/.abuild/${SIGN_NAME}.rsa"
    chmod 0400 "/home/${BUILD_USER}/.abuild/${SIGN_NAME}.rsa"
    [ -f "/etc/apk/keys/${SIGN_NAME}.rsa.pub" ] ||
        openssl rsa -pubout -in "${script_dir}"/sign.rsa -out "/etc/apk/keys/${SIGN_NAME}.rsa.pub"
    echo "PACKAGER_PRIVKEY=/home/${BUILD_USER}/.abuild/${SIGN_NAME}.rsa" > "/home/${BUILD_USER}/.abuild/abuild.conf"
    chown "${BUILD_USER}:${BUILD_USER}" -R "/home/${BUILD_USER}/"
}

mian()
{
    local alpinever="$1"
    [ -z "$alpinever" ] && exit 1
    local suffix="$2"
    [ -z "$suffix" ] && exit 1
    local ref="$3"
    [ -z "$ref" ] && exit 1

    prepare

    # a little hacky here:
    # abuild will use upper dir name "phpaltver" as repo name
    local builddir="/home/${BUILD_USER}/phpaltver/php${suffix}"
    [ -d "${builddir}" ] || {
        group "Prepare build dir"
        sudo -u "$BUILD_USER" mkdir -p "${builddir}"
    }
    cd "$builddir"

    group "Fetching files"
    fetch_apkbuild "$@"
    sudo -u "$BUILD_USER" abuild checksum

    group "Start build"
    local destdir="${script_dir}/${alpinever}"
    mkdir -p "$destdir"
    # allow user create subdirs
    chown "${BUILD_USER}:${BUILD_USER}" "$destdir"
    sudo -u user env \
        options="!check" \
        abuild -P "${script_dir}/${alpinever}" -r
    # chown back to root
    chown "root:root" "$destdir"

    #info "copy out things"
    #find /home/user/packages \
    #    -name '*.apk' \
    #    -type f \
    #    -exec cp {} "${script_dir}/${alpinever}" \;
        #sh -c 'fn=$1; cp $fn "'"${script_dir}"'/'"$alpinever"'-$(basename $fn)"' _ {} \;
}

mian "$@"
