Tag: xs-vcs-field-in-debian-control
Severity: info
Check: debian/control
Explanation: There is an XS-Vcs-&ast; field in the <code>debian/control</code> file. As
 of dpkg 1.14.6, the XS- prefix is no longer necessary. dpkg now
 recognizes these fields and handles them correctly. Consider removing
 the XS- prefix for this field.
