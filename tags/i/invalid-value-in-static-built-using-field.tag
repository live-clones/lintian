Tag: invalid-value-in-static-built-using-field
Severity: error
Check: fields/static-built-using
Explanation: The Static-Built-Using field contains invalid fields.
 .
 The Static-Built-Using field must consist of simple <code>source (=
 version)</code> clauses. Notably, it must use a strictly equal in the
 relation. For example:
 .
     Static-Built-Using: golang-github-mattn-go-xmpp (= 0.2.0-1)
 .
 Only first issue is shown.
See-Also: debian-policy 7.8
