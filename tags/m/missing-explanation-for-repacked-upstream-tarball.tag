Tag: missing-explanation-for-repacked-upstream-tarball
Severity: info
Check: debian/copyright/dep5
Explanation: The version of this package contains <tt>dfsg</tt>, <tt>ds</tt>,
 or <tt>debian</tt> which normally indicates that the upstream source
 has been repackaged, but there is no "Comment" or "Files-Excluded"
 field in its copyright file which explains the reason why.
 .
 Please add a comment why this tarball was repacked or add a suitable
 "Files-Excluded" field.
