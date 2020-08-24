Tag: default-mta-dependency-not-listed-first
Severity: warning
Check: fields/package-relations
Explanation: This package has a relationship with the mail-transport-agent
 or default-mta packages but does not specify the default-mta as an
 first option.
 .
 default-mta and mail-transport-agent should only ever be in a set of
 alternatives together, with default-mta listed in the primary
 position.
 .
 Please rearrange the dependencies such that default-mta is listed
 first.
