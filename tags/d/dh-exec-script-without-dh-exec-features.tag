Tag: dh-exec-script-without-dh-exec-features
Severity: warning
Check: debhelper
Explanation: The package uses dh-exec in at least one of its files, but does
 not use any of the features provided by dh-exec.
 .
 If the features provided by dh-exec is not needed, please remove the
 executable bit, and the dh-exec usage.
 .
 Note that starting with debhelper compatibility level 13, <code>dh_install</code>
 can directly substitute <code>DEB_HOST_*, DEB_BUILD_*, DEB_TARGET_*</code>.
 If you are using dh-exec to substitute these variables and are using a
 debhelper compatibility level of 13 or above, invoking dh-exec is redundant
 and it can be removed.
