Tag: unused-entry-in-debian-source-include-binaries
Severity: info
Check: debian/source/include-binaries
Explanation: An entry in <code>debian/source/include-binaries</code> does not exist
 in the patched source tree. Please remove the entry.
 .
 The format for the file is described in the manual page for
 <code>dpkg-source</code>.
See-Also: dpkg-source(1), Bug#528001, https://stackoverflow.com/questions/21057015/debian-include-binaries-format
