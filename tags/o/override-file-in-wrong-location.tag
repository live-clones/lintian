Tag: override-file-in-wrong-location
Severity: error
Check: debian/lintian-overrides
Explanation: Lintian overrides should be put in a regular file named
 /usr/share/lintian/overrides/<code>package</code>, not in a subdirectory
 named for the package or in the obsolete location under /usr/share/doc.
 See the Lintian documentation for more information on proper naming and
 format.
See-Also: lintian 2.4
