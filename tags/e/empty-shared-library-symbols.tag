Tag: empty-shared-library-symbols
Severity: error
Check: debian/shlibs
Renamed-From:
 pkg-has-symbols-control-file-but-no-shared-libs
Explanation: Although the package does not include any shared libraries, it does
 have a symbols control file. If you did include a shared library, check that
 the SONAME of the library is set and that it matches the contents of the
 symbols file.
 .
 SONAMEs are set with something like <code>gcc -Wl,-soname,libfoo.so.0</code>,
 where 0 is the major version of the library. If your package uses libtool,
 then libtool invoked with the right options should be doing this.
