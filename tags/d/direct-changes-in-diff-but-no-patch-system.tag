Tag: direct-changes-in-diff-but-no-patch-system
Severity: pedantic
Check: debian/patches
Explanation: The Debian diff.gz contains changes to files or creation of additional
 files outside the <code>debian</code> directory. Keeping the changes as separate
 patches under the control of a patch system allows for more fine grained
 control over them. The package will also more easily support possible
 future source package formats if all changes outside the <code>debian</code>
 directory are stored as patches.
 .
 If the diff only creates new files that can be copied into place by the
 package build rules, consider putting them in the <code>debian</code>
 directory rather than using a patch system.
