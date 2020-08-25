Tag: maintainer-script-should-not-parse-etc-passwd-or-group
Severity: warning
Check: scripts
See-Also: getent(1), nss(5)
Explanation: The maintainer script appears to manually parse <code>/etc/passwd</code>
 or <code>/etc/group</code> instead of using the <code>getent(1)</code> utility
 to display entries.
 .
 This bypasses the Name Service Switch (NSS), avoiding querying
 centralised or networked user databases such as LDAP, etc.
