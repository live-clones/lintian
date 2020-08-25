Tag: apache2-unsupported-dependency
Severity: warning
Check: apache2
Explanation: The package is declaring a module dependency within an Apache
 configuration file which is not supported there. Dependencies are supported in
 module '<code>.load</code>' files, and web application '<code>.conf</code>' files,
 conflicts in '<code>.load</code> files only.
