Tag: dh-exec-subst-unknown-variable
Severity: info
Check: debhelper
Explanation: The package uses a variable in one of its debhelper config
 files, but the variable is not one known to dpkg-architecture.
 .
 It is recommended to use a known subset of variables. If the package
 needs more than that, and makes sure the variable is exported through
 the build one way or the other, then this tag can be safely ignored
 or overridden.
