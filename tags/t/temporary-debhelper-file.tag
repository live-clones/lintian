Tag: temporary-debhelper-file
Severity: error
Check: debhelper/temporary
Explanation: The named file is a temporary Debhelper file.
 .
 The file should have been removed by <code>dh&lowbar;clean</code>. Sometimes
 that happens when an installable package was renamed or removed before the
 build directory was cleaned up.
See-Also:
 dh_clean(1)
