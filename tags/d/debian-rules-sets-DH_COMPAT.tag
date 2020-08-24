Tag: debian-rules-sets-DH_COMPAT
Severity: warning
Check: debian/rules
See-Also: debhelper(7)
Explanation: As of debhelper version 4, the DH_COMPAT environment variable is
 only to be used for temporarily overriding <tt>debian/compat</tt>. Any
 line in <tt>debian/rules</tt> that sets it globally should be deleted and
 a separate <tt>debian/compat</tt> file created if needed.
