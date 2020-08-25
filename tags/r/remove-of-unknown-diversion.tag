Tag: remove-of-unknown-diversion
Severity: error
Check: scripts
Explanation: The maintainer script removes a diversion that it didn't add. If
 you're cleaning up unnecessary diversions from older versions of the
 package, remove them in <code>preinst</code> or <code>postinst</code> instead of
 waiting for <code>postrm</code> to do it.
