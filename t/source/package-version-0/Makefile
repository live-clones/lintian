name = package-version-0
dir  = $(name)-0

all:
	mkdir $(dir)
	mkdir $(dir)/debian
	cp changelog copyright control rules $(dir)/debian/
	echo 7 > $(dir)/debian/compat
	dpkg-source -sn -b $(dir)

clean:
	rm -rf $(dir)
	rm -f $(name)_0*
