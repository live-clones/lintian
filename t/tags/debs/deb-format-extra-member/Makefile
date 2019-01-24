name = deb-format-extra-member

all:
	create-deb -o $(name).deb control

	# add the extra element in the end
	echo 'foo' > extra-stuff
	ar q $(name).deb extra-stuff

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary extra-stuff
	rm -rf root
