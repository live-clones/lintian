Tag: dpatch-build-dep-but-no-patch-list
Severity: warning
Check: debian/patches/dpatch
Explanation: Using dpatch requires you to explicitly list all patches you want
 to apply in debian/patches/00list. This package build-depends on dpatch,
 but does not provide a patch list. You should either remove the dpatch
 build dependency or add a patch list.
 .
 Note that an empty file cannot be represented in the Debian diff, so an
 empty patch list will disappear in the source package. If you intended
 for the series file to be empty, add a comment line.
