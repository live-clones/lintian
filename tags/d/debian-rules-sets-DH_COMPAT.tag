Tag: debian-rules-sets-DH_COMPAT
Severity: warning
Check: debian/rules
See-Also: debhelper(7)
Explanation: As of debhelper version 4, the DH&lowbar;COMPAT environment variable is
 only to be used for temporarily overriding <code>debian/compat</code>. Any
 line in <code>debian/rules</code> that sets it globally should be deleted and
 a separate <code>debian/compat</code> file created if needed.
