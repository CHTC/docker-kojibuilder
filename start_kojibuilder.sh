#!/bin/bash
__SUMMARY__=$(cat <<"__TLDR__"
start_kojibuilder.sh

Start a koji builder using podman
__TLDR__
)

# Defaults

Image=opensciencegrid/koji-builder:arm-release
Cert=$PWD/kojid.pem
Site_Defaults=$PWD/mock_site-defaults.cfg
KOJID_USER=$(hostname -f)
KOJI_HUB=kojihub2000.chtc.wisc.edu
export KOJID_USER KOJI_HUB

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
    echo >&2 "$__SUMMARY__"
    echo >&2
    echo >&2 "Usage: $Prog ..."
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

if [[ $* == -h || $* == --help ]]; then
    usage 0
fi

Foreground=

while getopts ':c:fi:s:u:' opt; do
    case $opt in
        c) Cert=$OPTARG ;;
        f) Foreground=true ;;
        i) Image=$OPTARG ;;
        s) Site_Defaults=$OPTARG ;;
        u) KOJID_USER=$OPTARG ;;
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
if [[ ! -f $Cert || ! -r $Cert ]]; then
    fail 4 "$Cert is not a readable file"
fi
if [[ ! -f $Site_Defaults || ! -r $Site_Defaults ]]; then
    fail 4 "$Site_Defaults is not a readable file"
fi

# get absolute paths
Cert=$(readlink -f "$Cert")
Site_Defaults=$(readlink -f "$Site_Defaults")


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
Args+=(-e KOJID_USER="$KOJID_USER")
Args+=(-e KOJI_HUB="$KOJI_HUB")
Args+=(-v "${Cert}:/etc/pki/tls/private/kojid.pem:ro")
Args+=(-v "${Site_Defaults}:/etc/mock/site-defaults.cfg")
Args+=(-v var_lib_mock:/var/lib/mock)
Args+=(-v var_lib_koji:/var/lib/koji)
Args+=(--name kojibuilder)
Args+=(--cap-add SYS_ADMIN)


exec podman run "${Args[@]}" "$Image"

fail 1 "Exec failed"


# vim:et:sw=4:sts=4:ts=8
