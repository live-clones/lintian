Tag: patch-system-but-no-source-readme
Severity: warning
Check: debian/patches
Explanation: This package build-depends on a patch system such as dpatch or
 quilt, but there is no <code>debian/README.source</code> file. This file is
 recommended for any package where <code>dpkg-source -x</code> does not result
 in the preferred form for making modifications to the package.
 .
 If you are using quilt and the package needs no other special handling
 instructions, you may want to add a <code>debian/README.source</code>
 referring to <code>/usr/share/doc/quilt/README.source</code>. Similarly, you
 can refer to <code>/usr/share/doc/dpatch/README.source.gz</code> for dpatch.
See-Also: policy 4.14
