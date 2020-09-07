Tag: repackaged-source-not-advertised
Severity: info
Check: debian/copyright/dep5
Explanation: The <code>debian/copyright</code> file mentions <code>Files-Excluded</code>
 but the source version has no repack suffix.
 .
 Repackaged sources are expected to indicate in their version number
 that they are different from the upstream release. It is commonly
 done by adding a repack suffix to the upstream version.
 .
 The choice of repack suffix depends on the reason for repackaging.
 When some files were excluded because licensing was a concern, the
 suffix <code>+dfsg</code> may be appropriate. In more generic cases, one
 could chose <code>+ds</code>.
 .
 Upstream sources are sometimes repackaged by accident when using old
 versions of <code>dh&lowbar;make</code>. It can also happen when a maintainer
 invokes the dh&lowbar;make option <code>--createorig</code> even though it is
 not needed.
 .
 According to the Debian Developer's Reference 6.7.8.2, the repack
 suffix is not required.
 .
 Please include such a suffix in the changelog version number to avoid
 this warning.
See-Also: Bug#471537, https://www.debian.org/doc/manuals/developers-reference/best-pkging-practices.html
