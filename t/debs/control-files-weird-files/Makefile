name = control-files-weird-files

all:
	touch triggers
	create-deb -o $(name).deb control triggers \
		special-file isinstallable

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary triggers
	rm -rf root/
