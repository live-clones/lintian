Tag: vcs-field-not-canonical
Severity: info
Check: fields/vcs
Explanation: The VCS-&ast; field contains an uncanonical URI. Please update to use
 the current canonical URI instead. This reduces the network bandwidth used
 and makes debcheckout work independent of the port forwarding and
 redirections properly working.
 .
 The definition of canonical used here is the URIs announced by the Alioth
 admins (see reference).
 .
 Note that this check is based on a list of known URIs. Lintian did not
 send an HTTP request to the URI to test this.
See-Also: https://lists.debian.org/debian-devel-announce/2011/05/msg00009.html