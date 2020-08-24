Tag: dh-exec-script-without-dh-exec-features
Severity: warning
Check: debhelper
Explanation: The package uses dh-exec in at least one of its files, but does
 not use any of the features provided by dh-exec.
 .
 If the features provided by dh-exec is not needed, please remove the
 executable bit, and the dh-exec usage.
