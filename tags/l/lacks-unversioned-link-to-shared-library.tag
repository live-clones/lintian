Tag: lacks-unversioned-link-to-shared-library
Severity: warning
Check: libraries/shared/links
Renamed-From:
 dev-pkg-without-shlib-symlink
Explanation: A <code>-dev</code> package is supposed to install an unversioned
 symbolic link that references the shared library by name.
 .
 There is no requirement that the names are otherwise related.
 .
 The dynamic linker uses the link to load the executable into memory.
 .
 In most cases, the symbolic link should be in the same folder as the library itself.
 A major exception are libraries installed under <code>/lib</code>. In those cases,
 the links should go into the corresponding folders under <code>/usr</code>.
 .
 For a library installed as <code>/lib/i386-linux-gnu/libXYZ.so.V</code>, a good link
 would be <code>/usr/lib/i386-linux-gnu/libXYZ.so</code>.
 .
 This tag is emitted for the library package and not for the <code>-dev</code> package.
 That is because Lintian looks for links after locating the library. The links can be
 in any of several installables, but there is only one library for each set of links
 pointing to it.
See-Also:
 debian-policy 8.4
 Bug#963099
