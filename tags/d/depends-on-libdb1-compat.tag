Tag: depends-on-libdb1-compat
Severity: error
Check: fields/package-relations
Explanation: The package seems to declare a relation on libdb1-compat.
 This library exists for compatibility with applications built against
 glibc 2.0 or 2.1. There is intentionally no corresponding development
 package. Do not link new applications against this library!
