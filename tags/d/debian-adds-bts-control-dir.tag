Tag: debian-adds-bts-control-dir
Severity: warning
Check: cruft
Renamed-From:
 diff-contains-bts-control-dir
Explanation: The Debian diff or native package contains files in a directory
 used by a bug tracking system, which are not useful in a diff or native
 package. <code>dpkg-source</code> will automatically exclude these if it
 is passed <code>-I</code> or <code>-i</code> for native and non-native packages
 respectively.
See-Also: dpkg-source(1)
