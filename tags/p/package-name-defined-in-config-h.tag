Tag: package-name-defined-in-config-h
Severity: warning
Check: includes/config-h
Explanation: This package installs a header file named <code>config.h</code> that
 uses the identifier PACKAGE&lowbar;NAME. It is probably incompatible with
 packages using autoconf.
 .
 Please remove the file or rename the identifier.
See-Also: Bug#733598
