Tag: remove-of-unknown-diversion
Severity: error
Check: maintainer-scripts/diversion
Explanation: The named maintainer script removes a diversion that it did not
 add.
 .
 When cleaning up unnecessary diversions from old versions of the package,
 please remove them in <code>preinst</code> or <code>postinst</code>. Do
 not use <code>postrm</code> for that purpose.
