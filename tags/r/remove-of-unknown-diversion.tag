Tag: remove-of-unknown-diversion
Severity: error
Check: scripts
Explanation: The maintainer script removes a diversion that it didn't add. If
 you're cleaning up unnecessary diversions from older versions of the
 package, remove them in <tt>preinst</tt> or <tt>postinst</tt> instead of
 waiting for <tt>postrm</tt> to do it.
