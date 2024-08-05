DESTDIR:=
PREFIX:=/usr/local
SYSCONFDIR:=/etc

.PHONY: install

install: kojibuilder.cfg kojibuilder.service mock_site-defaults.cfg start_kojibuilder.sh
	install -d                            $(DESTDIR)$(PREFIX)/sbin
	install -m 0755 start_kojibuilder.sh  $(DESTDIR)$(PREFIX)/sbin/start_kojibuilder.sh
	install -d                            $(DESTDIR)$(PREFIX)/lib/systemd/system
	install -m 0644 kojibuilder.service   $(DESTDIR)$(PREFIX)/lib/systemd/system/kojibuilder.service
	install -d                            $(DESTDIR)$(SYSCONFDIR)/osg
	install -b -C kojibuilder.cfg         $(DESTDIR)$(SYSCONFDIR)/osg/kojibuilder.cfg
	install -b -C mock_site-defaults.cfg  $(DESTDIR)$(SYSCONFDIR)/osg/kojibuilder-mock-site-defaults.cfg

