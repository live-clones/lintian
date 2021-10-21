Tag: apparently-corrupted-elf-binary
Severity: warning
Check: binaries/corrupted
Explanation: This appears to be an ELF file but readelf cannot parse it.
 .
 This may be a mistake or a corrupted file, you may need to
 install binutils-multiarch on the system running Lintian so that
 non-native binaries are handled correctly, or it may be a
 misidentification of a file as ELF that actually isn't.
