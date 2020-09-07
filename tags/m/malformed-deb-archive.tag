Tag: malformed-deb-archive
Severity: error
Check: deb-format
Explanation: The binary package is not a correctly constructed archive. A binary
 Debian package must be an ar archive with exactly three members:
 <code>debian-binary</code>, <code>control.tar.gz</code>, and one of
 <code>data.tar.gz</code>, <code>data.tar.bz2</code> or <code>data.tar.xz</code>
 in exactly that order. The <code>debian-binary</code> member must start
 with a single line containing the version number, with a major revision
 of 2.
See-Also: deb(5)
