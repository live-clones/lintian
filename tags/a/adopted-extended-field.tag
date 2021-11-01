Tag: adopted-extended-field
Severity: info
Check: debian/control/field/adopted
Renamed-From:
 xc-package-type-in-debian-control
 xs-testsuite-field-in-debian-control
 xs-vcs-field-in-debian-control
Explanation: A field in <code>debian/control</code> has an extension prefix
 but is also known without it.
 .
 Extension prefixes like <code>XS-&ast;</code> or <code>XC-&ast;</code> allow
 experimental fields to propagate to the right place when packages are
 built with <code>dpkg</code>. In this case, however, the field is
 also known without the prefix. In all likelihood the field was permanently
 adopted, and <code>dpkg</code> learned how to deal with it.
 .
 Please consider removing the extension prefix for the field name.
