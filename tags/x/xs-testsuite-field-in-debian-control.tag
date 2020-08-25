Tag: xs-testsuite-field-in-debian-control
Severity: info
Check: debian/control
Explanation: There is an XS-Testsuite field in the <code>debian/control</code> file. As
 of dpkg 1.17.10, the XS- prefix is no longer necessary. dpkg now
 recognizes this field and handles it correctly. As of dpkg 1.17.11 the
 field is automatically added by dpkg-source with the value "autopkgtest" if
 there is a non-empty <code>debian/tests/control</code> file present. Consider
 either removing the XS- prefix for this field or removing the field
 altogether if it contains just the "autopkgtest" value.
