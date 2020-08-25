Tag: quilt-patch-missing-description
Severity: info
Check: debian/patches/quilt
Explanation: quilt patch files should start with a description of patch. All
 lines before the start of the patch itself are considered part of the
 description. You can edit the description with <code>quilt header -e</code>
 when the patch is at the top of the stack.
 .
 As well as a description of the purpose and function of the patch, the
 description should ideally contain author information, a URL for the bug
 report (if any), Debian or upstream bugs fixed by it, upstream status,
 the Debian version and date the patch was first included, and any other
 information that would be useful if someone were investigating the
 patch and underlying problem. Please consider using the DEP 3 format for
 this information.
See-Also: https://dep-team.pages.debian.net/deps/dep3/
