Tag: override_dh_clean-does-not-call-dh_clean
Severity: warning
Check: debian/rules
Explanation: The <tt>debian/rules</tt> file for this package has an
 <tt>override_dh_clean</tt> target that does not reference <tt>dh_clean</tt>.
 .
 This can result in packages not cleaning up properly via <tt>debian/rules
 clean</tt>.
 .
 Please add a call to <tt>dh_clean</tt>.
See-Also: #884419, #884815
