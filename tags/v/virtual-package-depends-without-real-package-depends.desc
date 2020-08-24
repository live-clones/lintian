Tag: virtual-package-depends-without-real-package-depends
Severity: warning
Check: fields/package-relations
Explanation: The package declares a depends on a virtual package without listing a
 real package as an alternative first.
 .
 If this package could ever be a build dependency, it should list a real
 package as the first alternative to any virtual package in its Depends.
 Otherwise, the build daemons will not be able to provide a consistent
 build environment.
 .
 If it will never be a build dependency, this isn't necessary, but you may
 want to consider doing so anyway if there is a real package providing
 that virtual package that most users will want to use.
