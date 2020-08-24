Tag: default-mta-dependency-does-not-specify-mail-transport-agent
Severity: warning
Check: fields/package-relations
Explanation: This package has a relationship with the default-mta virtual
 package but does not specify the mail-transport-agent as an
 alternative.
 .
 default-mta and mail-transport-agent should only ever be in a set of
 alternatives together, with default-mta listed first.
 .
 Please add a "or" dependency on mail-transport-agent after
 default-mta.
