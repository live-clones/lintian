Tag: install-info-used-in-maintainer-script
Severity: error
Check: scripts
Explanation: This script apparently runs <code>install-info</code>. Updating the
 <code>/usr/share/info/dir</code> file is now handled automatically by
 triggers, so running <code>install-info</code> from maintainer scripts is no
 longer necessary.
 .
 If debhelper generated the maintainer script fragment, rebuilding the
 package with debhelper 7.2.17 or later will fix this problem.
