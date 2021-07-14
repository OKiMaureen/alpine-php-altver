#!/usr/bin/env bash
set -eo pipefail

# ./build.sh edge 7 98895c000a87c887cd4f0cac37e0c9b875ee43eb

self="$0"
script_dir=$(dirname "$self")

. "${script_dir}/utils.sh"

usage()
{
    printf "Usage:\n\t%s <alpinever> <suffix> <ref>\n\n\t" "$self"
    echo "where alpinever is used docker image," \
        "suffix is php version to build, ref is APKBUILD ref to use."
    printf "Example: \n\t%s edge 7 master\n" "$self"
}

build_apk()
{
    local alpinever="$1"
    [ -z "$alpinever" ] && usage && exit 1
    local suffix="$2"
    [ -z "$suffix" ] && usage && exit 1
    local ref="$3"
    [ -z "$ref" ] && usage && exit 1

    group "build php${suffix} apk for ${alpinever} using ${ref}"

    info "build PHP for ${alpinever} in docker"
    docker run --name alpine-php-altver \
        --rm \
        -t \
        -e "SIGN_NAME=${SIGN_NAME}" \
        -e "CI=${CI}" \
        -v "$(realpath .):/work:rw,rshared" \
        "alpine:${alpinever#v}" /work/indocker.sh \
            "$alpinever" "$suffix" "$ref"
}

if [ -z "${IN_BUILD_ALL}" ]
then
    build_apk "$@"
fi
