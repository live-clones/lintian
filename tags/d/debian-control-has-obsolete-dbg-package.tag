Tag: debian-control-has-obsolete-dbg-package
Severity: info
Check: debug/obsolete
Explanation: The <code>debian/control</code> file declares a
 <code>-dbg</code> package.
 .
 Debug packages are now generated automatically. It reduces the space requirements
 for archive mirrors for regular operations.
 .
 Please drop the <code>-dbg</code> package the <code>debian/control</code> file.
 Do not change it to a dummy package that depends on the <code>-dbgsym</code>
 package.
See-Also:
 https://wiki.debian.org/AutomaticDebugPackages
