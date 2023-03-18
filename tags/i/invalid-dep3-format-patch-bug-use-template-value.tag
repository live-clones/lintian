Tag: invalid-dep3-format-patch-bug-use-template-value
Severity: error
Check: debian/patches/dep3
Explanation: "Bug:" field contains template value, should be changed
 to appropriate value, as actual upstream URL, such as issue tracker
 (If there is no such URL, please remove this "Bug:" line).
 .
 e.g. "Bug: https://github.com/kubernetes/kubernetes/issues/3141592648777"
 .
See-Also: https://dep-team.pages.debian.net/deps/dep3/
