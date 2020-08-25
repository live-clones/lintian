Tag: patch-system-but-direct-changes-in-diff
Severity: warning
Check: debian/patches
Explanation: The package uses a patch system, but the Debian diff.gz contains
 changes to files or creation of additional files outside of the
 <code>debian</code> directory. This often indicates accidental changes that
 weren't meant to be in the package or changes that were supposed to be
 separated out into a patch. The package will also more easily support
 possible future source package formats if all changes outside the
 <code>debian</code> directory are stored as patches.
