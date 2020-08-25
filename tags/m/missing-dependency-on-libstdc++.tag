Tag: missing-dependency-on-libstdc++
Severity: error
Check: binaries
Experimental: yes
See-Also: policy 8.6.1
Explanation: The listed file appears to be linked against the C++ library, but the
 package doesn't depend on the C++ library package. Normally this indicates
 that ${shlibs:Depends} was omitted from the Depends line for this package
 in <code>debian/control</code>.
 .
 All shared libraries and compiled binaries must be run through
 dpkg-shlibdeps to find out any libraries they are linked against (often
 via the dh_shlibdeps debhelper command). The package containing these
 files must then depend on ${shlibs:Depends} in <code>debian/control</code> to
 get the proper package dependencies for those libraries.
