Tag: relative-library-search-path
Severity: error
Check: binaries/rpath
Explanation: The binary or shared library sets RPATH or RUNPATH. This
 overrides the normal library search path, possibly interfering with
 local policy and causing problems for multilib, among other issues.
 .
 As an aggravating factor, this search path is relative! It is probably
 not what you wanted.
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
 .
     <code>gcc test.o -o test -Wl,--rpath,/usr/local/lib</code>
 or
     <code>gcc test.o -o test -R/usr/local/lib</code>
 .
 and remove the <code>-Wl,--rpath</code> or <code>-R</code> argument.
 .
 You can also use the <code>chrpath</code> utility to remove the RPATH.
See-Also:
 https://wiki.debian.org/RpathIssue,
 Bug#732682,
 Bug#732674
