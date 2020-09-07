Tag: udeb-uses-unsupported-compression-for-data-tarball
Severity: error
Check: deb-format
Explanation: The data tarball of this udeb package is not compressed in format
 that udpkg (debian-installer's dpkg equivalent) does not support. Thus
 the udeb is likely to be uninstallable and could break daily or weekly
 d-i images.
 .
 Currently, udpkg supports .gz and .xz compressed tarballs.
