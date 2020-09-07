Tag: package-placeholder-in-symbols-file
Severity: warning
Check: debian/symbols
Explanation: The symbols file contains the placeholder  <code>&num;PACKAGE&num;</code>
 in the <code>Build-Depends-Package</code> field. During the build process, it
 will be replaced with the wrong value. There is no placeholder that works.
 .
 The development package for your shared library must be stated explicitly.
 .
 With the information, <code>dpkg-shlibdeps(1)</code> can calculate the
 installation prerequisites for your package from the build prerequisites.
See-Also:
 policy 8.6.3.2,
 deb-symbols(5),
 dpkg-shlibdeps(1),
 https://www.debian.org/doc/manuals/maint-guide/advanced.en.html#librarysymbols,
 Bug#944047
