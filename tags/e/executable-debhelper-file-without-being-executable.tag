Tag: executable-debhelper-file-without-being-executable
Severity: error
Check: debhelper
Explanation: The packaging file is marked executable, but it does not appear to be
 executable (e.g. it has no #! line).
 .
 If debhelper file is not supposed to be executable, please remove the
 executable bit from it.
