Tag: missing-debian-source-format
Severity: warning
Check: debian/source-dir
Explanation: Explicitly selecting a source format by putting the format in
 <code>debian/source/format</code> is recommended. This allows for
 future removal of the 1.0 default for the package source format and,
 depending on the source format, may allow unambiguous declaration of
 whether this package is native or non-native.
 .
 If you don't have a reason to stay with the old format for this package,
 please consider switching to "3.0 (quilt)" (for packages with a separate
 upstream tarball) or to "3.0 (native)" (for Debian native packages).
 .
 If you wish to keep using the old format, please create that file and put
 "1.0" in it to be explicit about the source package version. If you have
 problems with the 3.0 format, the dpkg maintainers are interested in
 hearing, at debian-dpkg@lists.debian.org, the (technical) reasons why the
 new formats do not suit you.
See-Also: dpkg-source(1), https://wiki.debian.org/Projects/DebSrc3.0
