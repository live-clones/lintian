Tag: dbg-package-missing-depends
Severity: warning
Check: fields/package-relations
Explanation: The given binary package has a name of the form of "X-dbg", indicating it
 contains detached debugging symbols for the package X. If so, it should
 depend on the corresponding package, generally with (= ${binary:Version})
 since the debugging symbols are only useful with the binaries created by
 the same build.
 .
 Note that the package being depended upon cannot be "Architecture:
 all".
 .
 If this package provides debugging symbols for multiple other
 packages, it should normally depend on all of those packages as
 alternatives. In other words, <code>pkga (= ${binary:Version}) | pkgb (=
 ${binary:Version})</code> and so forth.
