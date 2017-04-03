name = package-version-0
dir  = $(name)-0

all:
	mkdir $(dir)
	mkdir $(dir)/debian
	cp changelog copyright control rules $(dir)/debian/
	cp -R tests/ $(dir)/debian/
	echo $(DEFAULT_DH_COMPAT) > $(dir)/debian/compat
	mkdir $(dir)/debian/source
	echo 1.0 > $(dir)/debian/source/format
	dpkg-source -sn -b $(dir)

clean:
	rm -rf $(dir)
	rm -f $(name)_0*
