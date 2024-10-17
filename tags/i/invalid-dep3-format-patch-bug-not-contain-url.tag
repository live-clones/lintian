Tag: invalid-dep3-format-patch-bug-not-contain-url
Severity: warning
Check: debian/patches/dep3
Explanation: According to the DEP-3, "Bug:" line should contain upstream URL
 (note: it is not distribution vendor URL, such as Debian).
 e.g. "Bug: https://github.com/kubernetes/kubernetes/issues/3141592648777"
 .
 If there is no such URL, please remove this line.
 .
See-Also: https://dep-team.pages.debian.net/deps/dep3/
