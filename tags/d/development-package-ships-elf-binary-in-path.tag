Tag: development-package-ships-elf-binary-in-path
Severity: info
Check: binaries/location
Experimental: yes
Explanation: This development package (ie. from the <code>libdevel</code> section of
 the archive) installs an ELF binary within <code>$PATH</code>.
 .
 Commonly, executables in development packages provide values that are
 relevant for using the library. Source packages that use such
 development packages tend to execute those executables to discover how
 to use the library.
 .
 When performing a cross build, host architecture binaries are generally not
 executable. However, development packages need to be installed on the host
 architecture so such files are useless.
 .
 An alternative approach is to use <code>pkg-config(1)</code> or potentially
 splitting architecture-independent development tools into a separate
 package that can be marked <code>Multi-Arch: foreign</code>.
See-Also: Bug#794295, Bug#794103
