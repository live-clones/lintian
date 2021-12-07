Tag: no-strong-digests-in-dsc
Severity: error
Check: fields/checksums
Explanation: This <code>.dsc</code> file contains no
 <code>Checksum-Sha256</code> field and hence only weak digests.
 .
 This tag should show up only for source packages built with
 <code>dpkg-source</code> older than version 1.14.17 (from March 2008).
 It will probably not show up when you run Lintian locally but may be
 seen on
 https://lintian.debian.org/ for legacy source packages in the archive.
 .
 This tags can be fixed by rebuilding the source package
 with a more recent version of <code>dpkg-source</code>, i.e. by making
 a new upload.
