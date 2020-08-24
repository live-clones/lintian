Tag: diff-contains-arch-control-dir
Severity: warning
Check: cruft
Explanation: The Debian diff or native package contains files in an {arch} or
 .arch-ids directory or a directory starting with <tt>,,</tt> (used by baz
 for debugging traces). These are usually artifacts of the revision
 control system used by the Debian maintainer and not useful in a diff or
 native package. <tt>dpkg-source</tt> will automatically exclude these if
 it is passed <tt>-I</tt> or <tt>-i</tt> for native and non-native
 packages respectively.
See-Also: dpkg-source(1)
