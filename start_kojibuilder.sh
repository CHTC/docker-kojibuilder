#!/bin/bash
__SUMMARY__=$(cat <<"__TLDR__"
start_kojibuilder.sh

Start a koji builder using podman
__TLDR__
)

# Defaults

Image=opensciencegrid/koji-builder:arm-release
Cert=$PWD/kojid.pem
Env_File=$PWD/kojibuilder.cfg
Site_Defaults=$PWD/mock_site-defaults.cfg

export PS4='+ ${FUNCNAME:-(main)}:${LINENO}: '

Prog=${0##*/}
Progdir=$(dirname "$0")

ask_yn () {
    echo >&2 "$@"
    while read -r; do
        case $REPLY in
            [Yy]*) return 0;;
            [Nn]*) return 1;;
            *) echo >&2 "Enter yes or no";;
        esac
    done
    return 2  # EOF
}

eecho () {
    echo >&2 "$@"
}

eprintf () {
    # shellcheck disable=SC2059
    printf >&2 "$@"
}

fail () {
    set +o nounset
    ret=${1:-1}
    shift &>/dev/null || :
    if [[ -z $* ]]; then
        echo "$Prog: unspecified failure, exiting" >&2
    else
        echo "$Prog:" "$@" >&2
    fi
    exit "$ret"
}

usage () {
    eecho "$__SUMMARY__"
    eecho
    eecho "Usage: $Prog [options]"
    eecho
    eecho "-c [cert]    Path to cert file"
    eecho "-e [file]    Environment file containing image config"
    eecho "-f           Run in foreground"
    eecho "-i [image]   Container image to use"
    eecho "-s [file]    /etc/mock/site-defaults.cfg file"
    eecho "-u [user]    kojid user"
    exit "$1"
}

is_true () {
    case "${1-}" in
        [yY]*|[tT]*|1|*true) return 0 ;;
        [nN]*|[fF]*|0|*false) return 1 ;;
    esac
    return 2  # unknown
}

require_program () {
    command -v "$1" &>/dev/null ||
        fail 127 "Required program '$1' not found in PATH"
}

require_file () {
    local file="$1"
    local code="${2:-4}"
    if [[ ! -f $file || ! -r $file ]]; then
        fail "$code" "$file is not a readable file"
    fi
}

Foreground=

while getopts ':c:e:fi:s:u:h' opt; do
    case $opt in
        c) Cert=$OPTARG ;;
        e) Env_File=$OPTARG ;;
        f) Foreground=true ;;
        i) Image=$OPTARG ;;
        s) Site_Defaults=$OPTARG ;;
        u) KOJID_USER=$OPTARG ;;
        h) usage 0 ;;
        *) eecho Bad option "$opt"; usage 2 ;;
    esac
done

shift $((OPTIND - 1))
OPTIND=1

set -o nounset
IFS=$'\n\t'
unset GREP_OPTIONS POSIXLY_CORRECT

#
# Begin
#

require_program podman

if [[ $(id -u) != 0 ]]; then
    fail 3 "You must be root"
fi

require_file "$Cert"
require_file "$Site_Defaults"
require_file "$Env_File"

# get absolute paths
Cert=$(readlink -f "$Cert")
Site_Defaults=$(readlink -f "$Site_Defaults")
Env_File=$(readlink -f "$Env_File")


podman volume create --ignore var_lib_mock || fail 5 "Couldn't create var_lib_mock volume"
podman volume create --ignore var_lib_koji || fail 5 "Couldn't create var_lib_koji volume"


Args=()
Args=(--rm)
if $Foreground; then
    Args+=(-i)
    if [[ -t 0 && -t 1 ]]; then
        Args+=(-t)
    fi
else
    Args+=(--detach)
fi
Args+=(--env-file "$Env_File")
Args+=(-v "${Cert}:/etc/pki/tls/private/kojid.pem:ro")
Args+=(-v "${Site_Defaults}:/etc/mock/site-defaults.cfg")
Args+=(-v var_lib_mock:/var/lib/mock)
Args+=(-v var_lib_koji:/var/lib/koji)
Args+=(--name kojibuilder)
Args+=(--cap-add SYS_ADMIN)


exec podman run "${Args[@]}" "$Image"

fail 1 "Exec failed"


# vim:et:sw=4:sts=4:ts=8
