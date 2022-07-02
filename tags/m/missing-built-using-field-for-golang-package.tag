Tag: missing-built-using-field-for-golang-package
Severity: info
Check: languages/golang/built-using
Explanation: The stanza for a Golang installation package in the
 <code>debian/control</code> file does not include a
 <code>Built-Using</code> field that contains the <code>${misc:Built-Using}</code>
 substitution variable. 
 .
 The <code>dh-golang(1)</code> build system provides the <code>${misc:Built-Using}</code>
 variable. It is used when scheduling binNMUs.
 .
 Please add the following line to the relevant stanza:
 .
  <code>Built-Using: ${misc:Built-Using}</code>
