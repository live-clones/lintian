Tag: gzip-file-is-not-multi-arch-same-safe
Severity: error
Check: files/compressed/gz
Explanation: The gzip file contains a timestamp that will differ between
 architectures. Multi-Arch: same implies all shared files must be
 byte-for-byte identical.
 .
 This can usually be fixed by passing -n to gzip.
