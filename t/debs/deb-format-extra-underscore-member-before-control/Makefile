name = deb-format-extra-underscore-member-before-control

# Done by hand, create-deb cannot do this and it would
# be "too much effort" to make it be able to do it.
all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/$(name)
	install -m 0644 copyright changelog usr/share/doc/$(name)
	gzip -9n usr/share/doc/$(name)/changelog
	tar cfz data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	md5sum usr/share/doc/$(name)/* > md5sums
	echo 'foo' > _extra-stuff
	tar cfz control.tar.gz control md5sums
	ar rc $(name).deb \
	    debian-binary _extra-stuff control.tar.gz data.tar.gz
clean:
	rm -f *.tar.gz *.deb md5sums debian-binary _extra-stuff
	rm -rf usr
