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

fetch_apkbuild()
{
    local alpinever="$1"
    [ -z "$alpinever" ] && return 1
    local suffix="$2"
    [ -z "$suffix" ] && return 1
    local ref="$3"
    [ -z "$ref" ] && return 1

    info "fetching APKBUILD"
    curl -sfSL \
        "https://git.alpinelinux.org/aports/plain/community/php${suffix}/APKBUILD?id=${ref}" \
        -o "APKBUILD" \
        --retry 3 || {
        err "failed fetching APKBUILD"
        return 1
    }
    patch_file "${alpinever}" "APKBUILD"

    info "fetching patches,files"
    grep -ozPe 'sha512sums="\K(?s:.+?)"' APKBUILD |
    grep -oaPe '[a-zA-Z0-9]{128}\s+[^"]+' |
    while read -r line
    do
        local fn=${line##* }
        local sha512=${line%% *}
        if [ "${fn%%.tar.gz}" != "${fn}" ] ||
            [ "${fn%%.tar.xz}" != "${fn}" ] ||
            [ "${fn%%.tar.bz2}" != "${fn}" ]
        then
            continue
        fi
        trydownload "$fn" "https://git.alpinelinux.org/aports/plain/community/php${suffix}/${fn}?id=${ref}" "${sha512}"
    done
}
