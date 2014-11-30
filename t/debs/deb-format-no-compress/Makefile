name = deb-format-no-compress

# Done by hand, create-deb cannot do this and it would
# be "too much effort" to make it be able to do it.
all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/$(name)
	install -m 0644 copyright changelog usr/share/doc/$(name)
	gzip -9n usr/share/doc/$(name)/changelog
	tar cf data.tar usr
	chown 0:0 control
	chmod 644 control
	md5sum usr/share/doc/$(name)/* > md5sums
	tar cf control.tar control md5sums
	ar rc $(name).deb \
	    debian-binary control.tar data.tar
clean:
	rm -f *.tar *.deb md5sums debian-binary
	rm -rf usr