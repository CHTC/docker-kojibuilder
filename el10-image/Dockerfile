# OSG kojid container, Alma 10 version
# Requires CAP_SYS_ADMIN for chroot(1), unshare(1), and mounting tmpfs

# Copies all of the x86-64-v2 almalinux/10-base image into a new linux/amd64 image, changing the platform docker thinks the image is
FROM --platform=linux/amd64/v2 almalinux/10-base:10 AS alma10base

FROM --platform=linux/amd64 scratch
COPY --from=alma10base / /

LABEL maintainer OSG Software <help@osg-htc.org>

ARG clean_cache=""

RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked,id=dnf-alma10v2 <<__RUN__ bash
set -ex
dnf install -y epel-release 'dnf-command(config-manager)'
dnf config-manager --setopt=install_weak_deps=False --save > /dev/null
crb enable

cat > /etc/yum.repos.d/osg-distrepos.repo <<__REPO__
[osg-development]
name=osg-development
baseurl=https://koji.osg-htc.org/mnt/koji/repos-dist/osg-24-main-el10-development/latest/x86_64_v2
priority=98
enabled=1
gpgcheck=0

[osg-internal-development]
name=osg-internal-development
baseurl=https://koji.osg-htc.org/mnt/koji/repos-dist/osg-24-internal-el10-development/latest/x86_64_v2
priorty=98
enabled=1
gpgcheck=0

__REPO__

if [ -n "${clean_cache}" ]; then dnf clean all; fi

declare -a packages
packages+=(
    # common from software-base
    supervisor
    cronie
    #fetch-crl    # not available on EL10
    osg-ca-certs
    which
    less
    rpmdevtools
    fakeroot
    /usr/bin/ps

    # for the nslookup health check
    bind-utils

    # koji itself
    koji-builder
)
dnf install -y \${packages[*]}
# ^^ The '\$' is so docker doesn't expand it
touch /var/log/kojid.log
mkdir -p /etc/osg/image-init.d

__RUN__

COPY --chmod=0755 base/supervisord_startup.sh  /usr/local/sbin/
COPY --chmod=0755 base/crond_startup.sh  /usr/local/sbin/
COPY base/supervisord.conf  /etc/
COPY kojid-supervisord.conf  /etc/supervisord.d/kojid.conf
COPY koji_ca_cert.crt  /etc/pki/tls/certs/koji_ca_cert.crt
COPY --chmod=0755 create-config.sh  /etc/osg/image-init.d/create-config.sh
COPY --chmod=0755 healthcheck  /sbin/healthcheck
RUN chmod go-w /etc/supervisord.conf /usr/local/sbin/* /etc/cron.*/*

HEALTHCHECK --start-period=30s CMD /sbin/healthcheck

# Required environment variables
# ------------------------------
# The hostname of the koji-hub XMLRPC server
ENV KOJI_HUB=
# The username of the kojid; needs to match the commonName of the cert/key
ENV KOJID_USER=
# Optional environment variables
# ------------------------------
# Maximum jobs to run at one time
ENV KOJID_MAXJOBS=10
# Minimum free megabytes of disk before starting a new job
ENV KOJID_MINSPACE=4096
# Seconds before killing possibly hung rpm build
ENV KOJID_RPMBUILD_TIMEOUT=43200
# Work directory to do builds in
ENV KOJID_WORKDIR=/var/lib/koji
# SSL cert/key file for authentication; the CN must match KOJID_USER
ENV KOJID_CERTKEY=/etc/pki/tls/private/kojid.pem
