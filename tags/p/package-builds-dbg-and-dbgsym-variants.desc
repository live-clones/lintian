Tag: package-builds-dbg-and-dbgsym-variants
Severity: warning
Check: changes-file
See-Also: dh_strip(1), https://wiki.debian.org/AutomaticDebugPackages
Explanation: This package appears to build both -dbg and -dbgsym variants of a
 package. Only one package should contain the debug symbols
 .
 Usually the -dbg should be dropped in favour of the -dbgsym. However,
 in some cases (e.g. Python modules) the -dbg contains more than just 
 the debug symbols. In these cases the -dbgsym should not be built.
