Tag: uses-debhelper-compat-file
Severity: warning
Check: debhelper
Explanation: This package declares its debhelper compatibility level with the
 <code>debian/compat</code> file.
 .
 The recommended way to do so is to use the virtual package
 <code>debhelper-compat</code> instead.
 .
 From debhelper 14 onward, using <code>debian/compat</code> will not work
 anymore.
 .
 As such, unless you need an experimental or beta compatibility level, please
 remove the <code>debian/compat</code> file and add the
 <code>debhelper-compat</code> virtual package to your Build-Depends, for
 example:
 .
  Build-Depends: debhelper-compat (= 13)
See-Also: debhelper(7)
