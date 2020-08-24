Tag: uses-deprecated-compression-for-data-tarball
Severity: error
Check: deb-format
Explanation: The data portion of this binary package uses a deprecated compression
 format. Although dpkg will support extracting such binary packages for
 the foreseeable future, creating them will eventually be disallowed. A
 warning is emitted for lzma since dpkg 1.16.4, and for bzip2 since dpkg
 1.17.7.
 .
 For lzma, xz is the direct replacement. For bzip2 either gzip or xz can
 be used as a substitute, depending on the wanted properties: gzip for
 maximum compatibility and speed, and xz for maximum compression ratio.
