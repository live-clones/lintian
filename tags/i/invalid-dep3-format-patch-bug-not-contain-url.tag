Tag: invalid-dep3-format-patch-bug-not-contain-url
Severity: warning
Check: debian/patches/dep3
Explanation: According to the DEP-3, this patch's headers <code>Bug</code> field
 should contain an upstream bug URL.
 .
 For example: <code>Bug: https://github.com/kubernetes/kubernetes/issues/3141592648777</code>
 .
 If there is no such URL, please remove the <code>Bug</code> field.
See-Also: https://dep-team.pages.debian.net/deps/dep3/
