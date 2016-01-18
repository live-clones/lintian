name = files-mtime

all:

	mkdir -p root/usr/share/doc/$(name) root/usr/share/$(name)
	install -m0644 copyright changelog root/usr/share/doc/$(name)
	gzip -9 root/usr/share/doc/$(name)/changelog
	echo "Hallo World" | gzip -9c > root/usr/share/$(name)/foo.gz
	# we set the mtime to "right" now.  We use that as "now" to be
	# more robust about being built in the past/present/future or
	# in weird time-zones
	# NB: foo.gz is bad, but changelog.gz is "ok" (ignoring the
	# gzip header has a date).
	NOW="$$(date -d "$$(dpkg-parsechangelog -lchangelog -SDate)" +%s)" ; \
	  touch -m -d @"$$((NOW+1))" root/usr/share/$(name)/foo.gz && \
	  touch -m -d @"$$((NOW))" root/usr/share/doc/$(name)/changelog.gz

	create-deb --root root/ -o $(name).deb control

clean:
	rm -f *.tar.gz *.deb debian-binary md5sums
	rm -rf root/
