Tag: temporary-debhelper-file
Severity: error
Check: debhelper
See-Also: dh_clean(1)
Explanation: The package contains temporary debhelper files, which are normally
 removed by <code>dh&lowbar;clean</code>. The most common cause for this is that a
 binary package has been renamed or removed without cleaning the build
 directory first.
