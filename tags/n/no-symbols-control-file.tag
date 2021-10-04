Tag: no-symbols-control-file
Severity: info
Check: debian/shlibs
Explanation: Although the package includes a shared library, the package does not
 have a symbols control file.
 .
 dpkg can use symbols files in order to generate more accurate library
 dependencies for applications, based on the symbols from the library that
 are actually used by the application.
See-Also: dpkg-gensymbols(1), https://wiki.debian.org/UsingSymbolsFiles
