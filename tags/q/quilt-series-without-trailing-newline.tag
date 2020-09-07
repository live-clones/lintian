Tag: quilt-series-without-trailing-newline
Severity: error
Check: debian/patches/quilt
Explanation: The package contains a debian/patches/series file
 that doesn't end with a newline. dpkg-source may silently
 corrupt this file.
See-Also: Bug#584233
