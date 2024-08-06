#!/bin/bash
__SUMMARY__=$(cat <<__TLDR__
Start a Koji builder using Podman or Docker.  If using Podman, this needs
to be run as root, otherwise we can't give the container enough privileges
(builders need CAP_SYS_ADMIN).

Usage: $(basename "$0") [options]

    -c [cert]       Path to cert file
    -e [file]       Environment file containing image config
    -f              Run in foreground
    -n [network]    Use the given network (use '-n host' to use host networking)
    -i [image]      Container image to use
    -s [file]       /etc/mock/site-defaults.cfg file

The environment file needs to contain at least:
    KOJI_HUB        The hostname of the koji-hub server
    KOJID_USER      The user to log in as; this must match the CN of the
                    certificate used with -c.

See -h for help and defaults.
__TLDR__
)

#
# Defaults
#

DEFAULT_CERT=$PWD/kojid.pem
DEFAULT_ENV_FILE=$PWD/kojibuilder.cfg
DEFAULT_IMAGE=osgpreview/koji-builder:testing-arm
DEFAULT_SITE_DEFAULTS=$PWD/mock-site-defaults.cfg


eecho () {
    echo >&2 "$@"
}

fail () {
    set +x
    set +o nounset
    ret=${1:-1}
    shift &>/dev/null || :
    if [[ -z $* ]]; then
        eecho "unspecified failure, exiting"
    else
        eecho "$@"
    fi
    exit "$ret"
}

usage () {
    set +x
    eecho "$__SUMMARY__"
    eecho
    eecho "Defaults:"
    printf >&2 "Default %-24s   %s\n" \
        "cert" "$DEFAULT_CERT" \
        "environment file" "$DEFAULT_ENV_FILE" \
        "image" "$DEFAULT_IMAGE" \
        "mock site-defaults.cfg" "$DEFAULT_SITE_DEFAULTS"
    exit "$1"
}

is_true () {
    case "${1-}" in
        [yY]*|[tT]*|1|*true) return 0 ;;
        [nN]*|[fF]*|0|*false) return 1 ;;
    esac
    return 2  # unknown
}

require_file () {
    local file="$1"
    local code="${2:-4}"
    if [[ ! -f $file || ! -r $file ]]; then
        fail "$code" "$file is not a readable file"
    fi
}

docker_volume_exists () {
    # podman has a 'volume exists' command but docker doesn't
    "$Docker" volume ls -q | grep -Fxq "$1"
}

#
# Get arguments
#

Cert=$DEFAULT_CERT
Env_File=$DEFAULT_ENV_FILE
Foreground=
Image=$DEFAULT_IMAGE
Network=
Site_Defaults=$DEFAULT_SITE_DEFAULTS

while getopts ':c:e:fi:n:s:u:h' opt; do
    case $opt in
        c) Cert=$OPTARG ;;
        e) Env_File=$OPTARG ;;
        f) Foreground=true ;;
        i) Image=$OPTARG ;;
        n) Network=$OPTARG ;;
        s) Site_Defaults=$OPTARG ;;
        h) usage 0 ;;
        *) eecho Bad option "$opt"; usage 2 ;;
    esac
done

shift $((OPTIND - 1))
OPTIND=1

# Some boilerplate

export PS4='+ ${FUNCNAME:-(main)}:${LINENO}: '
set -o nounset
IFS=$'\n\t'
unset GREP_OPTIONS POSIXLY_CORRECT

#
#
# Begin
#
#

#
# Check container runtime
#

if command -v docker &>/dev/null; then
    Docker=docker
    if docker version 2>/dev/null | grep -q Podman; then
        # 'docker' is actually podman. We need to be root:
        if [[ $(id -u) != 0 ]]; then
            fail 3 "You must be root to run this with podman"
        fi
    fi
elif command -v podman &>/dev/null; then
    Docker=podman
    if [[ $(id -u) != 0 ]]; then
        fail 3 "You must be root to run this with podman"
    fi
else
    fail 127 "Neither docker nor podman were found"
fi


#
# Check required files
#

require_file "$Cert"
require_file "$Site_Defaults"
require_file "$Env_File"

# get absolute paths
Cert=$(readlink -f "$Cert")
Site_Defaults=$(readlink -f "$Site_Defaults")
Env_File=$(readlink -f "$Env_File")


#
# Create docker volumes for /var/lib/mock and /var/lib/koji if necessary
#

if ! docker_volume_exists var_lib_mock; then
    "$Docker" volume create var_lib_mock || fail 5 "Couldn't create var_lib_mock volume"
fi
if ! docker_volume_exists var_lib_koji; then
    "$Docker" volume create var_lib_koji || fail 5 "Couldn't create var_lib_koji volume"
fi


#
# Build argument list
#

Args=()
Args=(--rm)
if is_true "$Foreground"; then
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
if [[ $Network ]]; then
    Args+=(--net "$Network")
fi
Args+=(--cap-add SYS_ADMIN)


#
# Run!
#

exec "$Docker" run "${Args[@]}" "$Image"

fail 1 "Exec failed"


# vim:et:sw=4:sts=4:ts=8
