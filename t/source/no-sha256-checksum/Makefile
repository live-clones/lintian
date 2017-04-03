name = no-sha256-checksum
dir  = $(name)-1

all:
	mkdir -p $(dir)/debian/source
	cp changelog copyright control rules $(dir)/debian/
	cp -R tests/ $(dir)/debian/
	echo 9 > $(dir)/debian/compat
	echo "3.0 (native)" > $(dir)/debian/source/format
	tar cfz $(name)_1.tar.gz $(dir)
	subst-dsc $(name)_1.tar.gz < dsc.in > $(name)_1.dsc

clean:
	rm -rf $(dir)
	rm -f $(name)_1*
