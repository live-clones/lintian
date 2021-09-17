Tag: possible-gpl-code-linked-with-openssl
Severity: classification
Check: debian/copyright
Explanation: This package appears to be covered by the GNU GPL but depends on
 the OpenSSL libssl package and does not mention a license exemption or
 exception for OpenSSL in its copyright file. The GPL (including version
 3) is incompatible with some terms of the OpenSSL license, and therefore
 Debian does not allow GPL-licensed code linked with OpenSSL libraries
 unless there is a license exception explicitly permitting this.
 .
 If only the Debian packaging, or some other part of the package not
 linked with OpenSSL, is covered by the GNU GPL, please add a Lintian
 override for this tag. Lintian currently has no good way of
 distinguishing between that case and problematic packages.
See-Also:
 Bug#972181,
 http://meetbot.debian.net/debian-ftp/2020/debian-ftp.2020-03-13-20.02.html
