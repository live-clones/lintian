Tag: elf-error
Severity: warning
Check: binaries/corrupted
Renamed-From:
 apparently-corrupted-elf-binary
Explanation: The file appears to be in ELF format but readelf produced the indicated
 error when parsing it.
 .
 In case of a false positive, you may need to install <code>binutils-multiarch</code>
 so that ELF files from other architectures are handled correctly. It is also possible
 that the file is not actually in ELF format but was misidentified as such.
See-Also:
 https://refspecs.linuxfoundation.org/elf/elf.pdf,
 readelf(1)
