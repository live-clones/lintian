Tag: sharedobject-in-library-directory-missing-soname
Severity: error
Check: libraries/shared/soname/missing
Explanation: A shared object was identified in a library directory (a directory
 in the standard linker path) which doesn't have a SONAME. This is
 usually an error.
 .
 SONAMEs are set with something like <code>gcc -Wl,-soname,libfoo.so.0</code>,
 where 0 is the major version of the library. If your package uses libtool,
 then libtool invoked with the right options should be doing this.
 .
 To view the SONAME of a shared library, run <code>readelf -d</code> on the
 shared library and look for the tag of type SONAME.
