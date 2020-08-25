Tag: dh-exec-install-not-allowed-here
Severity: error
Check: debhelper
Explanation: The package uses a dh-exec-install construct in a debhelper
 config file, where it is not permitted.
 .
 The dh-exec-install constructs are only allowed in dh&lowbar;install's
 .install and dh&lowbar;installman's .manpages files, and nowhere else.
