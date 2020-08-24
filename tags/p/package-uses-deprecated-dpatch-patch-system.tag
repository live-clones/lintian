Tag: package-uses-deprecated-dpatch-patch-system
Severity: pedantic
Check: debian/patches/dpatch
Explanation: The dpatch patch system has been deprecated and superceded by the
 "3.0 (quilt)" source format.
 .
 Please migrate the patches in the <tt>debian/patches</tt> directory and
 the <tt>00list</tt> file to use this source format.
See-Also: dpatch(1), dpkg-source(1)
