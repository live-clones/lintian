Tag: missing-dependency-on-libc
Severity: error
Check: binaries/prerequisites
Explanation: The listed file appears to be linked against the C library, but the
 package doesn't depend on the C library package. Normally this indicates
 that ${shlibs:Depends} was omitted from the Depends line for this package
 in <code>debian/control</code>.
 .
 All shared libraries and compiled binaries must be run through
 dpkg-shlibdeps to find out any libraries they are linked against (often
 via the dh&lowbar;shlibdeps debhelper command). The package containing these
 files must then depend on ${shlibs:Depends} in <code>debian/control</code> to
 get the proper package dependencies for those libraries.
See-Also:
 policy 8.6.1
