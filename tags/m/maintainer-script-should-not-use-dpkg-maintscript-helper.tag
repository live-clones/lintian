Tag: maintainer-script-should-not-use-dpkg-maintscript-helper
Severity: warning
Check: scripts
Explanation: The maintainer script seems to make manual calls to the
 <code>dpkg-maintscript-helper(1)</code> utility.
 .
 Please use <code>package.maintscript</code> files instead; the
 <code>dh&lowbar;installdeb(1)</code> tool will do some basic validation of some of
 the commands listed in this file to catch common mistakes.
See-Also: dpkg-maintscript-helper(1), dh_installdeb(1)
