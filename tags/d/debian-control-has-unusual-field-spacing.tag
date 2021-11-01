Tag: debian-control-has-unusual-field-spacing
Severity: pedantic
Check: debian/control/field/spacing
Explanation: A field in the <code>debian/control</code> file has an unusual
 amount of whitespace after the colon.
 .
 The syntax for Deb822 files permits any kind of space, but according to Policy
 there is a convention to use a single space after the colon.
See-Also:
 policy 5.1
