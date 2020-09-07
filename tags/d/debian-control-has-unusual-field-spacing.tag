Tag: debian-control-has-unusual-field-spacing
Severity: pedantic
Check: debian/control
See-Also: policy 5.1
Explanation: The field on this line of <code>debian/control</code> has whitespace
 other than a single space after the colon. This is explicitly permitted
 in the syntax of Debian control files, but as Policy says, it is
 conventional to put a single space after the colon.
