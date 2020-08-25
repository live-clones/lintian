Tag: debug-package-for-multi-arch-same-pkg-not-coinstallable
Severity: info
Check: group-checks
Explanation: The debug package appear to be containing debug symbols for a
 "Multi-Arch: same" package, but the debug package itself is not
 "Multi-Arch: same". If so, it is not possible to have the debug
 symbols for all architecture variants of the binaries available
 at the same time.
 .
 Making a debug package co-installable with itself is very trivial,
 when installing the debug symbols beneath:
   <code>/usr/lib/debug/.build-id/&lt;XX&gt;/&lt;rest-id&gt;.debug</code>
 .
 dh&lowbar;strip does this in debhelper compat 9. Otherwise, the expected
 location of the debug symbols of a given ELF binary can be determined
 by using:
 .
  readelf -n &lt;binary-elf&gt; | \
      perl -ne 'print if s,^\s&ast;Build ID:\s&ast;(\S\S)(\S+),/usr/lib/debug/.build-id/$1/$2.debug,'
