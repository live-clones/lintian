Tag: debian-rules-uses-installed-python-versions
Severity: warning
Check: debian/rules
Explanation: The package appears to use <tt>py3versions -i</tt> to determine
 the "installed" Python versions.
 .
 However, this can cause issues if a Python transition is in progress
 as the <tt>-minimal</tt> variant of the previous version
 (eg. <tt>python3.X-minimal</tt>) remains installed in many environments.
 This variant then provides enough of an interpreter to count as being
 "installed" but not enough for the tests themselves to succeed in most
 cases. This then prevents the overall transition from taking place.
 .
 Please replace this will a call to all "supported" packages instead
 (eg. <tt>py3versions -s</tt> and ensure <tt>python3-all</tt> is listed
 in the build dependencies.
See-Also: https://lists.debian.org/debian-devel/2020/03/msg00280.html
