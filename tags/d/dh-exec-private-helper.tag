Tag: dh-exec-private-helper
Severity: error
Check: debhelper
Explanation: The packaging file uses dh-exec, but it does not use /usr/bin/dh-exec.
 .
 If running dh-exec with the default set of helpers is not desired,
 use its --with or --without options instead of directly using the
 desired helper.
