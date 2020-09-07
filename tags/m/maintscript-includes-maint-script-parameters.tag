Tag: maintscript-includes-maint-script-parameters
Severity: warning
Check: debhelper
Explanation: Lines in a <code>debian/&ast;.maintscript</code> correspond to
 <code>dpkg-maintscript-helper(1)</code> commands and parameters. However, the
 "maint-script-parameters" should not be included as debhelper will add those
 automatically. See <code>dh&lowbar;installdeb(1)</code> for more information.
