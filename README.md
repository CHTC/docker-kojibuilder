# docker-kojibuilder

A systemd service and supporting files for running a koji builder.

Instructions:

1.  Install docker or podman; start it if necessary
2.  Run `make install`
3.  Run `systemctl daemon-reload`
4.  Put a koji cert-key into `/etc/osg/kojibuilder.pem`
5.  Edit `/etc/osg/kojibuilder.cfg` as appropriate
6.  Run `systemctl start kojibuilder`

