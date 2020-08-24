Tag: missing-built-using-field-for-golang-package
Severity: info
Check: debian/control
Explanation: This package builds a binary package which does not include
 <tt>${misc:Built-Using}</tt> in its <tt>Built-Using</tt> control field.
 .
 The <tt>${misc:Built-Using}</tt> substvar is populated by
 <tt>dh-golang(1)</tt> and used for scheduling binNMUs.
 .
 Please add the following line to your package definition:
 .
  <tt>Built-Using: ${misc:Built-Using}</tt>
