Tag: override-file-in-wrong-location
Severity: error
Check: debian/lintian-overrides
Explanation: Lintian overrides should be put in a regular file named
 <code>/usr/share/lintian/overrides/<em>package</em></code>. They should
 not be in a subdirectory named like the package or in any location under
 <code>/usr/share/doc</code>, which is obsolete.
See-Also:
 lintian-manual 2.4
