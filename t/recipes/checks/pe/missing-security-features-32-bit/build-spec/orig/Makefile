MINGWCC = i686-w64-mingw32-gcc

sources = hello.c
safe = hello32.exe

staticbase = $(patsubst %.exe,%-static-base.exe,$(safe))
dataexecution = $(patsubst %.exe,%-data-execution.exe,$(safe))
unsafeseh = $(patsubst %.exe,%-unsafe-seh.exe,$(safe))

all: $(safe) $(staticbase) $(dataexecution) $(unsafeseh)

$(safe): $(sources)
	$(MINGWCC) -o $@ $^
	genpeimg -d +d $@
	genpeimg -d +n $@
	genpeimg -d -s $@

$(staticbase): $(safe)
	cp $< $@
	genpeimg -d -d $@

$(dataexecution): $(safe)
	cp $< $@
	genpeimg -d -n $@

$(unsafeseh): $(safe)
	cp $< $@
	# SEH is inverted
	genpeimg -d +s $@

.PHONY: clean
clean:
	rm -f $(safe) $(staticbase) $(dataexecution) $(unsafeseh)
