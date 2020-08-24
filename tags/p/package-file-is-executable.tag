Tag: package-file-is-executable
Severity: warning
Check: debhelper
Explanation: The packaging file is marked executable. For control, changelog and
 copyright there is no reason for them to be executable.
 .
 This tag is also emitted if a debhelper file is marked executable without
 using compat level 9, since debhelper does not execute them at lower
 compat levels.
