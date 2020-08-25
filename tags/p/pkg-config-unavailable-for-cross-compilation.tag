Tag: pkg-config-unavailable-for-cross-compilation
Severity: warning
Check: files/pkgconfig
Explanation: The specified pkg-config(1) file is installed to
 <code>/usr/lib/pkgconfig</code>. As the cross-compilation wrapper of pkg-config
 does not search this directory the file is unavailable under
 cross-compilation.
 .
 Please install the file to <code>/usr/lib/${DEB&lowbar;HOST&lowbar;MULTIARCH}/pkgconfig</code>
 instead.
 .
 For projects that use GNU Autotools, a simple method is moving to a debhelper
 compat level of 9 or higher. In the rare case that this file is architecture
 independent it can be installed to <code>/usr/share/pkgconfig</code> instead.
