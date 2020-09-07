Tag: vcs-field-uses-not-recommended-uri-format
Severity: warning
Check: fields/vcs
Explanation: The VCS-&ast; field uses a URI which doesn't match the recommended
 format, but still looks valid. Examples for not recommended URI formats
 are protocols that require authentication (like SSH). Instead where
 possible you should provide a URI that is accessible for everyone
 without authentication.
 .
 This renders debcheckout(1) unusable in these cases.
