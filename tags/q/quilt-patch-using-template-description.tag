Tag: quilt-patch-using-template-description
Severity: info
Check: debian/patches/quilt
Explanation: The patch contains a standard DEP 3 template description
 included by dpkg-source(1). Please consider replacing the template
 with a real description. You can edit the description by using
 <tt>quilt header -e</tt> when the patch is at the top of the stack.
 Alternatively, editing the patch in most text editors should work
 as well.
See-Also: https://dep-team.pages.debian.net/deps/dep3/
