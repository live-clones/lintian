Tag: vcs-field-not-canonical
Severity: info
Check: fields/vcs
Explanation: The VCS-&ast; field contains an uncanonical URI. Please update to use
 the current canonical URI instead. This reduces the network bandwidth used
 and makes debcheckout work independent of the port forwarding and
 redirections properly working.
 .
 Note that this check is based on a list of known URIs. Lintian did not
 send an HTTP request to the URI to test this.
