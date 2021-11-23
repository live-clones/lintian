Tag: maintscript-includes-maint-script-parameters
Severity: warning
Check: debian/maintscript
Explanation: The named <code>debian/&ast;.maintscript</code> file uses commands
 or parameters from <code>dpkg-maintscript-helper(1)</code>.
 .
 Debhelper will add them automatically. Please do not include them manually.
See-Also:
 dh_installdeb(1)
