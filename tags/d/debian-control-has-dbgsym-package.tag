Tag: debian-control-has-dbgsym-package
Severity: error
Check: debug/automatic
Explanation: The <code>debian/control</code> file declares a <code>-dbgsym</code>
 package. Those are now generated automatically.
 .
 Please remove the declaration and rely on the automatic process.
See-Also:
 Bug#858117,
 https://wiki.debian.org/DebugPackage
