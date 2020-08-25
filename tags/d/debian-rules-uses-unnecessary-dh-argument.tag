Tag: debian-rules-uses-unnecessary-dh-argument
Severity: warning
Check: debhelper
Explanation: The <code>debian/rules</code> file passes the specified argument to
 <code>dh $@</code> but it is enabled by default from this debhelper
 compatibility level onwards.
 .
 Please remove the argument from the call to <code>dh(1)</code>.
See-Also: debhelper(7), dh(1)
