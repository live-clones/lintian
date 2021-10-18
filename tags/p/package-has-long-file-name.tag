Tag: package-has-long-file-name
Severity: warning
Check: archive/file/name/length
Explanation: The package has a very long filename. This may complicate
 shipping the package on some media that put restrictions on the
 length of the filenames (such as CDs).
 .
 For architecture dependent packages, the tag is emitted based on the
 length of the longest architecture name rather than the name of the
 current architecture.
See-Also:
 https://lists.debian.org/debian-devel/2011/03/msg00943.html
