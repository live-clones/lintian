Tag: package-file-is-executable
Severity: warning
Check: debhelper
Explanation: The named packaging file is executable.
 .
 There is no reason to make the <code>control</code>, <code>changelog</code>
 or <code>copyright</code> files executable.
 .
 You will also see this tag for a Debhelper-related packaging file that is
 marked executable while using a <code>compat</code> level below 9.
