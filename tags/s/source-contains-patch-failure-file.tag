Tag: source-contains-patch-failure-file
Severity: warning
Check: cruft
Explanation: The Debian diff or native package contains a file that looks like
 the files left behind by the <code>patch</code> utility when it cannot
 completely apply a diff. This may be left over from a patch applied by
 the maintainer. Normally such files should not be included in the
 package.
