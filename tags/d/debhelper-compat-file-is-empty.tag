Tag: debhelper-compat-file-is-empty
Severity: error
Check: debhelper
See-Also: debhelper(7)
Explanation: The source package has an empty debian/compat file. This is an error,
 the compat level of debhelper should be in there. Note that only the first
 line of the file is relevant.
