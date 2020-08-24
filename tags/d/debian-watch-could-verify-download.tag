Tag: debian-watch-could-verify-download
Severity: warning
Check: debian/watch
See-Also: uscan(1)
Explanation: One or more upstream signing keys are present in the Debian package
 but are not being used.
 .
 Please enable the cryptographic verification of downloads with the
 "pgpsigurlmangle" option in your watch file or remove the key.
