Tag: debian-rules-parses-dpkg-parsechangelog
Severity: info
Check: debian/rules
Explanation: The rules file appears to be parsing the output of dpkg-parsechangelog to
 determine the current package version name, version, or timestamp, etc.
 .
 Since dpkg 1.16.1, this could be replaced by including the
 /usr/share/dpkg/pkg-info.mk Makefile library and using the
 DEB&lowbar;{SOURCE,VERSION} or SOURCE&lowbar;DATE&lowbar;EPOCH variables.
 .
 Using this library is not only cleaner and more efficient, it handles many
 corner-cases such as binNMUs, epoch versions, etc.
