#!/usr/bin/env ash
# shellcheck shell=bash

set -eo pipefail

SIGN_NAME="${SIGN_NAME:-signkey-60dd1390}"
BUILD_USER="${BUILD_USER:-user}"
ALPINE_VERSION="$1"

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

cd_builddir()
{
    package="$1"
    [ -z "$package" ] && exit 1
    # a little hacky here:
    # abuild will use upper dir name "phpaltver" as repo name
    local builddir="/home/${BUILD_USER}/phpaltver/$package"
    [ -d "${builddir}" ] || {
        info "Create build dir for $package" >&2
        sudo -u "$BUILD_USER" mkdir -p "${builddir}"
    }
    cd "$builddir"
}

build_package()
{
    package="$1"
    [ -z "$package" ] && exit 1

    group "Start build $package"
    cd_builddir "$package"
    local destdir="${script_dir}/${ALPINE_VERSION}"
    mkdir -p "$destdir"
    # allow user create subdirs
    chown "${BUILD_USER}:${BUILD_USER}" "$destdir"
    local ret=0
    sudo -u user env \
        DESCRIPTION="phpaltver" \
        options="!check" \
        abuild -P "${script_dir}/${ALPINE_VERSION}" -r || ret=$?
    echo # abuild sometimes writes a ^[[0m at last without not lf
    # chown back to root
    chown "root:root" "$destdir"
    return $ret
}

prepare_php()
{
    local suffix="$2"
    [ -z "$suffix" ] && exit 1
    local ref="$3"
    [ -z "$ref" ] && exit 1

    group "Fetching files for php$suffix"
    cd_builddir "php$suffix"
    fetch_apkbuild "$ALPINE_VERSION" "php$suffix" "$ref"
    sudo -u "$BUILD_USER" abuild checksum
}

depend_merge()
{
    local packages="$1"
    [ -z "$packages" ] && exit 1
    local package="$2"
    [ -z "$package" ] && exit 1

    cd_builddir "$package"
    : echo depend_merge "$package" >&2

    local depends
    depends="$(grep -oPe '^\s*depends="\K[^"]+' APKBUILD)"
    depends="$depends $(grep -oPe '^\s*makedepends="\K[^"]+' APKBUILD)"
    local depend
    local used
    for depend in $depends
    do
        if echo "$packages" | grep -e "$depend" >/tmp/nonce
        then
            depend_merge "$packages" "$depend"
            used="${used} ${depend}"
        fi
    done
    : echo depend_merge "$package" = "$used" >&2
    echo "$package"
}

prepare_pecl()
{
    local suffix="$2"
    [ -z "$suffix" ] && exit 1
    local ref="$3"
    [ -z "$ref" ] && exit 1

    local packages=""
    local package

    info "fetching file list for pecl packages"
    curl -sfSL \
        "https://git.alpinelinux.org/aports/plain/community?id=${ref}" \
        -o "/tmp/list.html" \
        --retry 3 || {
        err "failed fetching file list"
        return 1
    }
    grep -oPe '>\Kphp'"${suffix}"'-[^<]+' /tmp/list.html > /tmp/list
    rm /tmp/list.html

    while read -r package
    do
        packages="$packages $package"
    done < /tmp/list
    sed -i '/^php7-pecl-couchbase$/d' /tmp/list # for unsolvable api change
    # download APKBUILDs and files
    for package in $packages
    do
        cd_builddir "$package"

        group "Fetching files for ${package}"
        fetch_apkbuild "$ALPINE_VERSION" "$package" "$ref"
        #sudo -u "$BUILD_USER" abuild checksum
        #echo # abuild sometimes writes a ^[[0m at last without not lf
    done
    # donot rm /tmp/list
}

build_pecl()
{
    local suffix="$2"
    [ -z "$suffix" ] && exit 1
    local ref="$3"
    [ -z "$ref" ] && exit 1

    local packages=""
    local package

    # read package list from /tmp/list
    while read -r package
    do
        packages="$packages $package"
    done < /tmp/list

    # resolve dependencies and rearrange
    for package in $packages
    do
        depend_merge "$packages" "$package"
    done > /tmp/merged_list

    # use php to make it unique
    packages=$("php$suffix" -r '$''a=array_unique(preg_split("/\s/",file_get_contents("/tmp/merged_list")));ksort($''a); echo implode(" ",$''a)."\n";')
    rm /tmp/merged_list

    # start build
    for package in $packages
    do
        build_package "$package" || {
            warn "failed to build pecl extension $package"
        }
        find "${script_dir}/${ALPINE_VERSION}/phpaltver/x86_64" \
            -type f \
            -name "${package}*.apk" \
            -exec apk add --no-progress {} \;
    done
}

install_all()
{
    #shellcheck disable=SC2046
    apk add --no-progress $(find "${script_dir}/${ALPINE_VERSION}/phpaltver/x86_64" -type f -name "*.apk")
}

mian()
{
    prepare
    prepare_php "$@"
    prepare_pecl "$@"
    chown -R "${BUILD_USER}:${BUILD_USER}" "/home/${BUILD_USER}"
    build_package "php$2"
    install_all
    build_pecl "$@"
}

mian "$@"
