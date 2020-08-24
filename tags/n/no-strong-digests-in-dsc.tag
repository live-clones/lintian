Tag: no-strong-digests-in-dsc
Severity: error
Check: fields/checksums
Explanation: This .dsc file contains no Checksum-Sha256 field and hence only
 weak digests.
 .
 This issue will only show up for source packages built with
 dpkg-source before 1.14.17 (March 2008) and hence will probably never
 show up when you run Lintian locally but only on
 https://lintian.debian.org/ for source packages in the archive.
 .
 Accordingly it can be fixed by simply rebuilding the source package
 with a more recent dpkg-source version, i.e. by uploading a new
 Debian release of the package.
