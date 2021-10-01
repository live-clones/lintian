Tag: debug-file-with-no-debug-symbols
Severity: warning
Check: binaries/debug-symbols/detached
Explanation: The binary is installed as a detached "debug symbols" ELF file,
 but it does not appear to have debug information associated with it.
 .
 A common cause is not passing <code>-g</code> to GCC when compiling.
 .
 Implementation detail: Lintian checks for the ".debug&lowbar;line" and the
 ".debug&lowbar;str" sections. If either of these are present, the binary
 is assumed to contain debug information.
See-Also: Bug#668437
