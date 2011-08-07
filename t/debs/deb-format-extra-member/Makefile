name = deb-format-extra-member

all:
	mkdir -p root/usr/share/doc/$(name)
	cp copyright changelog root/usr/share/doc/$(name)
	gzip -9 root/usr/share/doc/$(name)/changelog

	create-deb -o $(name).deb --root root control

	# add the extra element in the end
	echo 'foo' > extra-stuff
	ar q $(name).deb extra-stuff

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary extra-stuff
	rm -rf root
