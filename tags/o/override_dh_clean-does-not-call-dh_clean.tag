Tag: override_dh_clean-does-not-call-dh_clean
Severity: warning
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package has an
 <code>override&lowbar;dh&lowbar;clean</code> target that does not reference <code>dh&lowbar;clean</code>.
 .
 This can result in packages not cleaning up properly via <code>debian/rules
 clean</code>.
 .
 Please add a call to <code>dh&lowbar;clean</code>.
See-Also: Bug#884419, Bug#884815
