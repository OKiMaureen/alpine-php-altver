#!/usr/bin/env bash

# a bash/ash script utilities

if [ "${CI}" = "true" ] || [ -t 1 ]
then
    _log()
    {
        local prefix=$1
        shift
        local color=$1
        shift
        printf "\033[%sm[%s]\033[0m $*\n" "${color}" "${prefix}"
    }
    info()
    {
        _log "IFO" "1" "$@"
    }
    warn()
    {
        _log "WRN" "36;1" "$@"
    }
    err()
    {
        _log "ERR" "31;1" "$@"
    }
else
    info()
    {
        echo "$@"
    }
    warn()
    {
        echo "$@"
    }
    err()
    {
        echo "$@"
    }
fi

if [ "${CI}" = "true" ]
then
    group()
    {
        echo "::group::$*"
    }
else
    group()
    {
        info "$@"
    }
fi

trydownload()
{
    local fn="$1"
    local url="$2"
    local sha512="$3"
    local realsum

    if [ -n "$sha512" ]
    then
        realsum=$(sha512sum "${fn}" 2>&-) || :
        if [ "$realsum" = "$sha512" ]
        then
            info "${fn} is already presented"
            return 0
        fi
    fi
    local x ; for x in $(seq 3)
    do
        info "fetching ${fn} (try $x)"
        curl -sfSL "$url" -o "${fn}" || {
            warn "failed fetching ${fn} (try $x)"
            continue
        }
        if [ -z "${sha512}" ]
        then
            return 0
        fi
        realsum=$(sha512sum "${fn}" 2>&-)
        if [ "${realsum%% *}" = "$sha512" ]
        then
            return 0
        else
            warn "sha512 not match for ${fn}"
            warn "${realsum%% *} vs $sha512"
        fi
    done
    return 1
}
