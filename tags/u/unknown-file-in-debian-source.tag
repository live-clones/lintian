Tag: unknown-file-in-debian-source
Severity: error
Check: debian/source-dir
Explanation: The source package contains a file in <code>debian/source/</code>
 that Lintian does not know about. Currently the following files are recognized:
 .
  - <code>format</code>
  - <code>include-binaries</code>
  - <code>lintian-overrides</code>
  - <code>options</code>
  - <code>patch-header</code>
 .
 Perhaps the name of one of the those files was accidentally mistyped.
