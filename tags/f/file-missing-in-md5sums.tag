Tag: file-missing-in-md5sums
Severity: warning
Check: md5sums
Explanation: The package contains a file which isn't listed in the md5sums control
 file.
 .
 Usually, this error occurs during the package build process if the
 <tt>debian/tmp/</tt> directory is touched after <tt>dh_md5sums</tt>
 is run.
