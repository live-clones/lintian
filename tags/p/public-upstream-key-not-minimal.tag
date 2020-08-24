Tag: public-upstream-key-not-minimal
Severity: info
Check: debian/upstream/signing-key
See-Also: uscan(1)
Explanation: The package contains a public upstream signing key with extra
 signatures. The signatures are unnecessary and take up space in
 the archive.
 .
 Please export the upstream key again with the command:
 .
  $ gpg --armor --export --export-options export-minimal,export-clean
 .
 and use that key instead of the key currently in the source package.
