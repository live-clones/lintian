Tag: pkg-config-multi-arch-wrong-dir
Severity: error
Check: files/pkgconfig
Explanation: The arch all pkg-config file contains a reference to a multi-arch path.
 .
 This can be usually be fixed by moving this file to a multi-arch path.
 .
 Another likely cause is using debhelper 9 or newer (thus enabling
 multi-arch paths by default) on a package without multi-arch support.
 The usual cure in this case is to update it for multi-arch.
 .
 Last but not least, this file could contain a reference to a cross
 architecture (like for instance an x86&lowbar;64-linux-gnu pkg-config file
 referencing an i386-linux-gnu file). In this case the usual cure is to
 fix this path.
