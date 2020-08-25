Tag: unknown-file-in-debian-source
Severity: error
Check: debian/source-dir
Explanation: The source package contains a file in debian/source/ that Lintian
 doesn't know about. Currently the following files are recognized:
 .
  - format
  - include-binaries
  - lintian-overrides
  - options
  - patch-header
 .
 This tag is emitted in case you mistyped the name of one of the above
 files.
