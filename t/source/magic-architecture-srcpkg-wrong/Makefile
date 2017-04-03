name = magic-architecture-srcpkg-wrong
dir  = $(name)-1.0

all:
	mkdir $(dir)
	echo 'Some upstream README' > $(dir)/README
	tar -c -f $(name)_1.0.orig.tar.gz -z $(dir)
	mkdir $(dir)/debian
	cp changelog copyright control rules $(dir)/debian/
	cp -R tests/ $(dir)/debian/
	echo $(DEFAULT_DH_COMPAT) > $(dir)/debian/compat
	echo '# foo' > $(dir)/debian/watch
	mkdir $(dir)/debian/source
	echo 1.0 > $(dir)/debian/source/format
	dpkg-source -DArchitecture="amd64 any" -sp -b $(dir)

clean:
	rm -rf $(dir)
	rm -f $(name)_1.0*
