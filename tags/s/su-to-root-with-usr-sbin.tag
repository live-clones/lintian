Tag: su-to-root-with-usr-sbin
Severity: warning
Check: menu-format
Explanation: The command in a <code>menu</code> item or in a Desktop file uses
 refers to the full path <code>/usr/sbin/su-to-root</code>.
 .
 Since the sarge release (Debian 3.1) <code>su-to-root</code> is located in
 <code>/usr/bin</code>. The location <code>/usr/sbin/su-to-root</code> is a
 symbolic link to ensure compatibility. It may be dropped in the future.
 .
 Since <code>su-to-root</code> is now available in <code>/usr/bin</code> you
 can use it without an absolute path.
