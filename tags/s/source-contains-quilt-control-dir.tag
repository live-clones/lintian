Tag: source-contains-quilt-control-dir
Severity: warning
Check: cruft
Explanation: The patched sources contains files in a directory
 used by quilt, which are not useful in a diff or native package.
 <code>dpkg-source</code> will automatically exclude these if it is passed
 <code>-I</code> or <code>-i</code> for native and non-native packages
 respectively.
See-Also: dpkg-source(1)
