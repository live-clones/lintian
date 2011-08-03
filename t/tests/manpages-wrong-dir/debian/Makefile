all: pecho.1.gz jecho jecho.1 zecho.1.gz

%.gz: %
	gzip --best $<

%.1: %
	pod2man --section 1  $< > $@

jecho zecho: pecho
	sed s/$</$@/g $< > $@
	chmod 0755 $@

clean:
	rm -f pecho.1.gz jecho jecho.1 zecho*
