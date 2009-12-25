# A simple makefile to build a *.o file and a *.a file to install to test
# the OCaml checks for dangling *.cmx files.
all: symbol.a

symbol.a: symbol.o
	ar rv symbol.a symbol.o

symbol.o: symbol.c
	cc -c symbol.c
