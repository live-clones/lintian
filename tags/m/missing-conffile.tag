Tag: missing-conffile
Severity: error
Check: conffiles
Renamed-From: conffile-is-not-in-package
Explanation: The conffiles control file lists this path, but the path does
 not appear to exist in the package. Lintian may also emit this tag
 when the file exists, but the canonical name is used in the
 "conffiles" control file (e.g. if a parent segment are symlinks).
 .
 Note that dpkg and Lintian strips all whitespace from the right hand
 side of each line. Thus it is not possible for a file ending with
 trailing whitespace to be marked as a conffile.
