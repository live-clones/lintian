Tag: debian-rules-calls-pwd
Severity: warning
Check: debian/rules
Renamed-From: debian-rules-should-not-use-pwd
Explanation: The <code>debian/rules</code> file for this package appears to use the
 variable $(PWD) to refer to the current directory. This variable is not
 set by GNU make and therefore will have whatever value it has in the
 environment, which may not be the actual current directory. Some ways of
 building Debian packages (such as through sudo) will clear the PWD
 environment variable.
 .
 Instead of $(PWD), use $(CURDIR), which is set by GNU make, ignores the
 environment, and is guaranteed to always be set.
