Tag: invalid-dep3-format-patch-maybe-bug-debian
Severity: warning
Check: debian/patches/dep3
Explanation: According to the DEP-3, this patch's headers
 <code>Bug</code> field should contain an upstream bug URL instead
 of a Debian BTS URL.
 .
 If you want to refer to a Debian BTS URL, you should use the
 <code>Bug-Debian</code> field instead.
 .
 For example: <code>Bug-Debian: https://bugs.debian.org/927914</code>
See-Also: https://dep-team.pages.debian.net/deps/dep3/
