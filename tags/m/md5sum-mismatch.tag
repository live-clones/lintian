Tag: md5sum-mismatch
Severity: error
Check: md5sums
Explanation: The md5sum listed for the file does not match the actual file
 contents.
 .
 Usually, this error occurs during the package build process if the
 <code>debian/tmp/</code> directory is touched after <code>dh&lowbar;md5sums</code>
 is run.
 .
 Font files regenerated at post-install time by <code>t1c2pfb</code>
 should be overridden.
