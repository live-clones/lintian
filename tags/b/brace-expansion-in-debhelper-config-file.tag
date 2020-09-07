Tag: brace-expansion-in-debhelper-config-file
Severity: warning
Check: debhelper
Explanation: This debhelper config file appears to use shell brace expansion
 (such as <code>{foo,bar}</code>) to specify files. This happens to work due
 to an accident of implementation but is not a supported feature. Only
 <code>?</code>, <code>&ast;</code>, and <code>[...]</code> are supported.
See-Also: debhelper(1)
