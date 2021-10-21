Tag: custom-library-search-path
Severity: error
Check: binaries/rpath
Renamed-From: binary-or-shlib-defines-rpath
Explanation: The binary or shared library sets RPATH or RUNPATH. This
 overrides the normal library search path, possibly interfering with
 local policy and causing problems for multilib, among other issues.
 .
 The only time a binary or shared library in a Debian package should
 set RPATH or RUNPATH is if it is linked to private shared libraries
 in the same package. In that case, place those private shared
 libraries in <code>/usr/lib/*package*</code>. Libraries used by
 binaries in other packages should be placed in <code>/lib</code> or
 <code>/usr/lib</code> as appropriate, with a proper SONAME, in which case
 RPATH/RUNPATH is unnecessary.
 .
 To fix this problem, look for link lines like:
     gcc test.o -o test -Wl,--rpath,/usr/local/lib
 or
     gcc test.o -o test -R/usr/local/lib
 and remove the <code>-Wl,--rpath</code> or <code>-R</code> argument. You can also
 use the chrpath utility to remove the RPATH.
See-Also: https://wiki.debian.org/RpathIssue
