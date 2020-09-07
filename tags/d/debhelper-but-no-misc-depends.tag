Tag: debhelper-but-no-misc-depends
Severity: warning
Check: debhelper
See-Also: debhelper(7)
Explanation: The source package uses debhelper, but it does not include
 ${misc:Depends} in the given binary package's debian/control entry. Any
 debhelper command may add dependencies to ${misc:Depends} that are
 required for the work that it does, so recommended best practice is to
 always add ${misc:Depends} to the dependencies of each binary package if
 debhelper is in use.
