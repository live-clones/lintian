Tag: binary-with-bad-dynamic-table
Severity: error
Check: binaries/corrupted
Explanation: This appears to be an ELF file. According to readelf, the
 program headers suggests it should have a dynamic section, but
 readelf cannot find it.
 .
 If it is meant to be external debugging symbols for another file,
 it should be installed under /usr/lib/debug. Otherwise, this
 could be a corrupt ELF file.
