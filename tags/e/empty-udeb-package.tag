Tag: empty-udeb-package
Severity: info
Check: files/empty-package
Experimental: yes
Explanation: This udeb package appears to be empty, and its description does
 not say that it's a metapackage or a package. This is often due to
 problems with updating debhelper &ast;.install files during package
 renames or similar problems where installation rules don't put files
 in the correct place.
 .
 If the package is deliberately empty, you can avoid this tag by
 using one of the following phrases "metapackage", "dummy", "dependency
 package", or "empty package" in the long description of the udeb.
