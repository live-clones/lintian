Tag: uses-debhelper-compat-file
Severity: pedantic
Check: debhelper
Explanation: This package uses a <code>debian/compat</code> file to denote the
 required debhelper compatibility number.
 .
 However, debhelper has replaced <code>debian/compat</code> with the
 <code>debhelper-compat</code> virtual package for most circumstances.
 .
 Packages not using an experimental or beta compatibility level should
 Build-Depend on the <code>debhelper-compat</code> virtual package, for
 example:
 .
  Build-Depends: debhelper-compat (= 13)
See-Also: debhelper(7)
