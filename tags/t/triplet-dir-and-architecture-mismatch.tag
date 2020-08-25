Tag: triplet-dir-and-architecture-mismatch
Severity: error
Check: files/architecture
See-Also: policy 9.1.1
Explanation: This package contains a directory under <code>/lib</code> or
 <code>/usr/lib</code> which doesn't match the proper triplet for the
 binary package's architecture. This is very likely to be a mistake
 when indicating the underlying build system where the files should be
 installed.
