Tag: package-placeholder-in-symbols-file
Severity: warning
Check: debian/symbols
Explanation: The symbols file contains the placeholder  <tt>&num;PACKAGE&num;</tt>
 in the <tt>Build-Depends-Package</tt> field. During the build process, it
 will be replaced with the wrong value. There is no placeholder that works.
 .
 The development package for your shared library must be stated explicitly.
 .
 With the information, <tt>dpkg-shlibdeps(1)</tt> can calculate the
 installation prerequisites for your package from the build prerequisites.
See-Also:
 policy 8.6.3.2,
 deb-symbols(5),
 dpkg-shlibdeps(1),
 https://www.debian.org/doc/manuals/maint-guide/advanced.en.html#librarysymbols,
 #944047
