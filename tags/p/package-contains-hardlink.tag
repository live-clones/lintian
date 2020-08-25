Tag: package-contains-hardlink
Severity: warning
Check: files/hard-links
Explanation: The package contains a hardlink in <code>/etc</code> or across different
 directories. This might not work at all if directories are on different
 filesystems (which can happen anytime as the system administrator sees fit),
 certain filesystems such as AFS don't even support cross-directory hardlinks
 at all.
 .
 For configuration files, certain editors might break hardlinks, and so
 does dpkg in certain cases.
 .
 A better solution might be using symlinks here.
See-Also: policy 10.7.3
