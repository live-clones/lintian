Tag: dpatch-missing-description
Severity: info
Check: debian/patches/dpatch
Explanation: dpatch files should carry a description of the included patch.
 Description lines start with "## DP:".
 .
 As well as a description of the purpose and function of the patch, the
 description should ideally contain author information, a URL for the bug
 report (if any), Debian or upstream bugs fixed by it, upstream status,
 the Debian version and date the patch was first included, and any other
 information that would be useful if someone were investigating the
 patch and underlying problem. Please consider using the DEP 3 format for
 this information.
See-Also: https://dep-team.pages.debian.net/deps/dep3/
