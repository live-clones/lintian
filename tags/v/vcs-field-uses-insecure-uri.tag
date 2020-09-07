Tag: vcs-field-uses-insecure-uri
Severity: info
Check: fields/vcs
Explanation: The Vcs-&ast; field uses an unencrypted transport protocol for the
 URI. It is recommended to use a secure transport such as HTTPS for
 anonymous read-only access.
 .
 Note that you can often just exchange e.g. git:// with https:// for
 repositories. Though, in some cases (bzr's "lp:" or CVS's pserver) it
 might not be possible to use an alternative url and still have a
 working (anonymous read-only) repository.
