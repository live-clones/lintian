Tag: source-contains-waf-binary
Severity: error
Check: build-systems/waf
Explanation: The source tarball contains a waf binary. This file is a Python
 script with an embedded bzip2 archive, which is uncompressed and unpacked
 at runtime.
 .
 Although corresponding sources can be easily extracted, FTP Team does not
 consider waf binary as the preferred form of modification; it should be
 provided unpacked instead, or completely removed, if possible.
 .
 You might want to follow these guidelines to obtain an unpacked waf:
 https://wiki.debian.org/UnpackWaf
See-Also: https://wiki.debian.org/UnpackWaf, Bug#654523
