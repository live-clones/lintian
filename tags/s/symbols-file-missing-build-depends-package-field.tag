Tag: symbols-file-missing-build-depends-package-field
Severity: info
Check: debian/shlibs
Explanation: The symbols file for this package does not contain a
 <code>Build-Depends-Package</code> meta-information field.
 .
 This field specifies the name of the <code>-dev</code> package associated
 to the library and is used by <code>dpkg-shlibdeps(1)</code> to make sure
 that the dependency generated is at least as strict as the
 corresponding build dependency.
 .
 This is useful as allows packages to not hardcode this information
 multiple times.
 .
 Note that the format of <code>deb-symbols(5)</code> files requires that the
 <code>&ast; Build-Depends-Package:</code> line should start in column one of
 the file and not be indented to align with the symbols themselves.
 Please do not use the placeholder <code>&#35;PACKAGE&#35;</code>. The
 development package for your shared library must be stated explicitly.
See-Also:
 policy 8.6.3.2,
 deb-symbols(5),
 dpkg-shlibdeps(1),
 https://www.debian.org/doc/manuals/maint-guide/advanced.en.html#librarysymbols,
 Bug#944047
