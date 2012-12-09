all: bad.pfb good.pfb

%.pfb: %.raw
	t1asm $< > $@

clean:
	rm -f *.pfb

