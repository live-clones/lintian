name = debian-source-dir-traversal-2
dir  = $(name)-1

all:
	mkdir $(dir)
	mkdir $(dir)/debian
	cp changelog copyright control rules $(dir)/debian/
	# Link to the lab entry - should trigger a myriad of
	# "unknown-file-in-debian-source" tags, if lintian is vulnerable
	ln -s ../ $(dir)/debian/source
	tar cfz $(name)_1.tar.gz $(dir)
	subst-dsc $(name)_1.tar.gz < dsc.in > $(name)_1.dsc

clean:
	rm -rf $(dir)
	rm -f $(name)_1*
