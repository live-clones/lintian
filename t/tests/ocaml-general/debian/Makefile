# A simple makefile to build a *.o file and a *.a file to install to test
# the OCaml checks for dangling *.cmx files.
all: symbol.a symbol-dev.a

%.a: %.o
	ar rv $@ $<

symbol-dev.o: symbol.c
	cc -c $< -o $@
