Tag: missing-notice-file-for-apache-license
Severity: error
Check: debian/copyright/apache-notice
Explanation: The package appears to be licensed under the Apache 2.0 license and
 a <code>NOTICE</code> file (or similar) exists in the source tree. However, no
 files called <code>NOTICE</code> or <code>NOTICE.txt</code> are installed in any
 of the binary packages.
 .
 The Apache 2.0 license requires distributing of such files:
 .
  (d) If the Work includes a "NOTICE" text file as part of its
      distribution, then any Derivative Works that You distribute must
      include a readable copy of the attribution notices contained
      within such NOTICE file [..]
 .
 Please include the file in your package, for example by adding
 <code>path/to/NOTICE</code> to a <code>debian/package.docs</code> file.
See-Also: /usr/share/common-licenses/Apache-2.0
