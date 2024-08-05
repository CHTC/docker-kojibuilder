.PHONY: install

install: kojibuilder.cfg kojibuilder.service mock_site-defaults.cfg start_kojibuilder.sh
	install -d                            $(DESTDIR)/usr/local/sbin
	install -m 0755 start_kojibuilder.sh  $(DESTDIR)/usr/local/sbin/start_kojibuilder.sh
	install -d                            $(DESTDIR)/usr/local/lib/systemd/system
	install -m 0644 kojibuilder.service   $(DESTDIR)/usr/local/lib/systemd/system/kojibuilder.service
	install -d                            $(DESTDIR)/etc/osg
	install -b -C kojibuilder.cfg         $(DESTDIR)/etc/osg/kojibuilder.cfg
	install -b -C mock_site-defaults.cfg  $(DESTDIR)/etc/osg/kojibuilder-mock-site-defaults.cfg

