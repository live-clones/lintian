Tag: missing-built-using-field-for-golang-package
Severity: info
Check: debian/control
Explanation: This package builds a binary package which does not include
 <code>${misc:Built-Using}</code> in its <code>Built-Using</code> control field.
 .
 The <code>${misc:Built-Using}</code> substvar is populated by
 <code>dh-golang(1)</code> and used for scheduling binNMUs.
 .
 Please add the following line to your package definition:
 .
  <code>Built-Using: ${misc:Built-Using}</code>
