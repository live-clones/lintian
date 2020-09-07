Tag: no-md5sums-control-file
Severity: info
Check: md5sums
Explanation: This package does not contain an md5sums control file. This control
 file listing the MD5 checksums of the contents of the package is not
 required, but if present debsums can use it to verify that no files
 shipped with your package have been modified. Providing it is
 recommended.
 .
 If you are using debhelper to create your package, just add a call to
 <code>dh&lowbar;md5sums</code> at the end of your binary-indep or binary-arch
 target, right before <code>dh&lowbar;builddeb</code>.
