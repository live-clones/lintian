name = unpack-numerical-owner

all:
	create-deb -o $(name).deb --tar-opts='--numeric-owner' \
	     control

clean:
	rm -f *.tar.gz *.deb debian-binary
	rm -rf root/
