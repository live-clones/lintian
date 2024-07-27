Tag: invalid-dep3-format-patch-maybe-bug-debian
Severity: warning
Check: debian/patches/dep3
Explanation: According to the DEP-3, "Bug:" line should contain upstream URL
 but now it seems to be Debian BTS number. If so, you should use "Bug-Debian:"
 field and set URL as its value, instead of "Bug:" field.
 .
 e.g. "Bug-Debian: https://bugs.debian.org/927914"
 .
See-Also: https://dep-team.pages.debian.net/deps/dep3/
