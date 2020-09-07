Tag: orig-tarball-missing-upstream-signature
Severity: warning
Check: upstream-signature
Explanation: The packaging includes an upstream signing key but the corresponding
 <code>.asc</code> signature for one or more source tarballs are not included
 in your .changes file.
 .
 Please ensure a
 <code>&lt;package&gt;&lowbar;&lt;version&gt;.orig.tar.&lt;ext&gt;.asc</code> file
 exists in the same directory as your
 <code>&lt;package&gt;&lowbar;&lt;version&gt;.orig.tar.&lt;ext&gt;</code> tarball prior
 to <code>dpkg-source --build</code> being called.
 .
 If you are repackaging your source tarballs for Debian Free Software
 Guidelines compliance reasons, ensure that your package version includes
 <code>dfsg</code> or similar.
 .
 Sometimes, an upstream signature must be added for an <code>orig.tar.gz</code>
 that is already present in the archive. Please include the upstream sources
 again with <code>dpkg-genchanges -sa</code> while the signature is also present.
 Your upload will be accepted as long as the new <code>orig.tar.gz</code> file
 is identical to the old one.
See-Also: Bug#954743, Bug#872864
