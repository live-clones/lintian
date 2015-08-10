# This is the correct way to build a lib

CC=gcc
CFLAGS=-g -Wall -Winline -O2

OBJS=baz.o extra.o
SHOBJS=baz.sho extra.sho
NOPICOBJS = $(SHOBJS)

all: libbaz1.a libbaz2.a libbaz1.so.1.0.3b libbaz2.so libbaz3.so.1.0.3b \
	libbaz.so

libbaz2.so: libbaz2.so.1.0
	ln -sf $^ $@
libbaz2.so.1.0: libbaz2.so.1.0.3b
	ln -sf $^ $@

# Oops, forget the soname altogether
libbaz1.so.1.0.3b: $(NOPICOBJS)
	$(CC) -o $@ -shared $^ -lc

libbaz2.so.1.0.3b: $(SHOBJS)
	$(CC) -o $@ -shared -Wl,-soname,libbaz2.so.1.0 $^ -lc

# Non-PIC. We can't test this on all architectures
libbaz3.so.1.0.3b: $(NOPICOBJS)
	$(CC) -o $@ -shared -Wl,-soname,libbaz3.so.1 $^ -lc

# Non-versioned SONAME.
libbaz.so: $(SHOBJS)
	$(CC) -o $@ -shared -Wl,-soname,libbaz.so $^ -lc

#%.o-noreentrant: %.c
#	$(CC) $(CFLAGS) -o $@ -c $<

%.sho: %.c
	$(CC) $(CFLAGS) -D_REENTRANT -fPIC -o $@ -c $<

%.o: %.c
	$(CC) $(CFLAGS) -D_REENTRANT -o $@ -c $<

libbaz2.a: $(OBJS)
	ar cq $@ $(OBJS)
	strip --strip-unneeded --remove-section=.comment \
		--remove-section=-note $@
	ranlib $@

# The pic one in the .a (wrong), no archive table
libbaz1.a: $(SHOBJS)
	ar cqS $@ $^
	strip --strip-unneeded --remove-section=.comment \
		--remove-section=-note $@
clean:
	rm -f *.a *.o *.so* *.sho
