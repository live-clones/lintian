Tag: changelog-file-not-compressed
Severity: error
Check: debian/changelog
Explanation: Changelog files should be compressed using "gzip -9". Even if they
 start out small, they will become large with time.
See-Also: policy 12.7
