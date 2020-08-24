Tag: weak-dependency-on-misc-depends
Severity: warning
Check: debhelper
See-Also: debhelper(7)
Explanation: The source package declares a weak dependency on ${misc:Depends} in
 the given binary package's debian/control entry. A stronger dependency, that
 is one that ensures the package's installation, is required so that the
 additional commands are available to the maintainer scripts when they are run.
