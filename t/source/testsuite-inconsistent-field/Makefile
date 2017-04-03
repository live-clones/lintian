name = testsuite-inconsistent-field
dir  = $(name)-1.0

all:
	mkdir $(dir)
	mkdir $(dir)/debian
	cp changelog copyright control rules $(dir)/debian/
	cp -R tests/ $(dir)/debian/
	echo $(DEFAULT_DH_COMPAT) > $(dir)/debian/compat
	mkdir $(dir)/debian/source
	echo 1.0 > $(dir)/debian/source/format
	dpkg-source -sn -b $(dir)
	sed -i '/^Testsuite: /d' *.dsc

clean:
	rm -rf $(dir)
	rm -f $(name)_*
