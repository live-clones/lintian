Tag: not-using-po-debconf
Severity: error
Check: debian/po-debconf
Explanation: This package seems to be using debconf templates, but it does not
 use po-debconf to make translations possible (<code>debian/po</code> doesn't
 exist). Debian Policy requires that all packages using debconf use a
 gettext-based translation system.
See-Also: policy 3.9.1
