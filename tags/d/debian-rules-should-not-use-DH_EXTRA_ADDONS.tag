Tag: debian-rules-should-not-use-DH_EXTRA_ADDONS
Severity: warning
Check: debian/rules
Explanation: The DH&lowbar;EXTRA&lowbar;ADDONS variable is designed for local or downstream build
 use and not for use in debian/rules
 .
 dh(1)'s <code>--with</code> should be used instead.
