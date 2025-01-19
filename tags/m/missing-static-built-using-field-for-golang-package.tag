Tag: missing-static-built-using-field-for-golang-package
Severity: info
Renamed-From: missing-built-using-field-for-golang-package
Check: languages/golang/built-using
Explanation: The stanza for a Golang installation package in the
 <code>debian/control</code> file does not include a
 <code>Static-Built-Using</code> field that contains the <code>${misc:Static-Built-Using}</code>
 substitution variable. 
 .
 The <code>dh_golang(1)</code> build system provides the <code>${misc:Static-Built-Using}</code>
 variable. It is used when scheduling binNMUs.
 .
 Please add the following line to the relevant stanza:
 .
     Static-Built-Using: ${misc:Static-Built-Using}
