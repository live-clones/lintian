Tag: debian-watch-uses-insecure-uri
Severity: info
Check: debian/watch
Explanation: The watch file uses an unencrypted transport protocol for the
 URI such as http:// or ftp://. It is recommended to use a secure
 transport such as HTTPS for anonymous read-only access.
 .
 Upstream may already provide a HTTPS variant of the URI. If not,
 please contact them and ask them to consider adding one.
