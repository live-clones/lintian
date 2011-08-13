name = deb-format-lzma

all:
	create-deb -o $(name).deb -c lzma control

clean:
	rm -f *.tar.gz *.tar.lzma *.deb md5sums debian-binary
	rm -rf root
