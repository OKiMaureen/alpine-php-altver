#!/usr/bin/env ash
# shellcheck shell=bash

set -eo pipefail

script_dir=$(dirname "$0")

. "${script_dir}/utils.sh"

patch_file()
{
    local alpinever="$1"
    local fn="$2"
    #local phpver
    #phpver=$(grep -oPe 'pkgver=\K[78]\.\d+' APKBUILD)
    #local phpmaj="${phpver%%.*}"
    #local phpmin="${phpver##*.}"
    case "$fn" in
        "APKBUILD")
            if [ 'v3.10' = "$alpinever" ] || [ 'v3.11' = "$alpinever" ]
            then
                info "patching APKBUILD for enchant-enchant2 changes"
                sed -i 's|enchant2-dev|enchant-dev|g' APKBUILD
                sed -i 's|[a-zA-Z0-9]\{128\}\s\+enchant-2.patch||g' APKBUILD
                sed -i 's|enchant-2.patch||g' APKBUILD
            fi
            info "patching APKBUILD for version alignment"
            #shellcheck disable=SC2016
            sed -i 's|^depends="\$pkgname-common"$|depends="\$pkgname-common=\$pkgver-r\$pkgrel"|' APKBUILD
            ;;
        *)
            info "skipping patch $fn"
            ;;
    esac
}

fetch_files()
{
    local package="$1"
    [ -z "$package" ] && return 1

    info "fetching patches and files for ${package}"
    local line
    local fn
    local sha512
    local skip=""
    local sources
    sources=$(grep -ozPe '\nsource="\K(?s:.+?)"' APKBUILD | grep -oaPe '[^"]+')
    for source in $sources
    do
        if [ "${source##"http://"}" != "${source}" ] ||
            [ "${source##"https://"}" != "${source}" ] ||
            [ "${source##"ftp://"}" != "${source}" ] ||
            [ "${source%%::*}" != "${source}" ]
        then
            # let abuild download it
            skip="$skip $source"
        fi
    done

    grep -ozPe '\nsha512sums="\K(?s:.+?)"' APKBUILD |
    grep -oaPe '[a-zA-Z0-9]{128}\s+[^"]+' |
    while read -r line
    do
        fn=${line##* }
        sha512=${line%% *}

        if echo "$skip" | grep -e "$fn" >>/tmp/nonce
        then
            continue
        fi

        if [ "${fn%%.tar.gz}" != "${fn}" ] ||
            [ "${fn%%.tar.xz}" != "${fn}" ] ||
            [ "${fn%%.tar.bz2}" != "${fn}" ] ||
            [ "${fn%%.tgz}" != "${fn}" ] ||
            [ "${fn%%.txz}" != "${fn}" ]
        then
            continue
        fi

        trydownload "$fn" "https://git.alpinelinux.org/aports/plain/community/${package}/${fn}?id=${ref}" "${sha512}"
    done
}

fetch_apkbuild()
{
    local alpinever="$1"
    [ -z "$alpinever" ] && return 1
    local package="$2"
    [ -z "$package" ] && return 1
    local ref="$3"
    [ -z "$ref" ] && return 1

    info "fetching APKBUILD for $package"
    curl -sfSL \
        "https://git.alpinelinux.org/aports/plain/community/$package/APKBUILD?id=${ref}" \
        -o "APKBUILD" \
        --retry 3 || {
        err "failed fetching APKBUILD"
        return 1
    }
    
    if [ "php7" = "${package}" ] || [ "php8" = "${package}" ]
    then
        patch_file "${alpinever}" "APKBUILD"
    fi

    fetch_files "$package"
}