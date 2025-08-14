# OSG kojid container, Alma 10 version
# Requires CAP_SYS_ADMIN for chroot(1), unshare(1), and mounting tmpfs

# Copies all of the x86-64-v2 almalinux/10-base image into a new linux/amd64 image, changing the platform docker thinks the image is
FROM hub.opensciencegrid.org/osgpreview/software-base:24-el10

LABEL maintainer OSG Software <help@osg-htc.org>

ARG clean_cache=""

RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked,id=dnf-alma10 <<__RUN__ bash
set -ex

if [ -n "${clean_cache}" ]; then dnf clean all; fi

declare -a packages
packages+=(
    openssl
    # for the nslookup health check
    bind-utils

    # koji itself
    koji-builder
)
dnf install -y \${packages[*]} --enablerepo=osg-internal-development
# ^^ The '\$' is so docker doesn't expand it
touch /var/log/kojid.log

__RUN__

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
