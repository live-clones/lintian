Tag: invalid-dep3-format-patch-bug-field-default-value
Severity: error
Check: debian/patches/dep3
Explanation: This patch's headers <code>Bug</code> field contains a default value
 and should be changed to an appropriate value, such as an actual upstream bug URL.
 .
 For example: <code>Bug: https://github.com/kubernetes/kubernetes/issues/3141592648777</code>
 .
 If there is no such URL, please remove the <code>Bug</code> field.
See-Also: https://dep-team.pages.debian.net/deps/dep3/
