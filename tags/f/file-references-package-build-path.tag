Tag: file-references-package-build-path
Severity: info
Check: files/contents
Explanation: The listed file or maintainer script appears to reference
 the build path used to build the package as specified in the
 <code>Build-Path</code> field of the <code>.buildinfo</code> file.
 .
 This is likely to cause the package to be unreproducible, but it may
 also indicate that the package will not work correctly outside of the
 maintainer's own system.
 .
 Please note that this tag will not appear unless the
 <code>.buildinfo</code> file contains a <code>Build-Path</code> field. That
 field is optional. You may have to set
 <code>DEB&lowbar;BUILD&lowbar;OPTIONS=buildinfo=+path</code> or use
 <code>--buildinfo-option=--always-include-path</code> with
 <code>dpkg-buildpackage</code> when building.
See-Also: https://reproducible-builds.org/, https://wiki.debian.org/ReproducibleBuilds/BuildinfoFiles, dpkg-genbuildinfo(1)
