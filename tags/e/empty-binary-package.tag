Tag: empty-binary-package
Severity: warning
Check: files/empty-package
Explanation: This binary package appears to be empty, and its description does
 not say that it's a metapackage or a transitional package. This is
 often due to problems with updating debhelper &ast;.install files during
 package renames or similar problems where installation rules don't put
 files in the correct place.
 .
 If the package is deliberately empty, please mention in the package long
 description one of the phrases "metapackage", "dummy", "dependency
 package", or "empty package".
 .
 Previously, Lintian also accepted the use of "virtual package". This
 was removed to avoid overloading the term. If you have been relying on
 the phrase "virtual package" to avoid this warning, please replace it
 with one of the others.
