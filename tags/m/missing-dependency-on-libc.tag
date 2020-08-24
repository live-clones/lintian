Tag: missing-dependency-on-libc
Severity: error
Check: binaries
See-Also: policy 8.6.1
Explanation: The listed file appears to be linked against the C library, but the
 package doesn't depend on the C library package. Normally this indicates
 that ${shlibs:Depends} was omitted from the Depends line for this package
 in <tt>debian/control</tt>.
 .
 All shared libraries and compiled binaries must be run through
 dpkg-shlibdeps to find out any libraries they are linked against (often
 via the dh_shlibdeps debhelper command). The package containing these
 files must then depend on ${shlibs:Depends} in <tt>debian/control</tt> to
 get the proper package dependencies for those libraries.
