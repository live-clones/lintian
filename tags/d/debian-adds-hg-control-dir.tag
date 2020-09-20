Tag: debian-adds-hg-control-dir
Severity: warning
Check: cruft
Renamed-From:
 diff-contains-hg-control-dir
Explanation: The Debian diff or native package contains files in a .hg
 directory. These are usually artifacts of the revision control system
 used by the Debian maintainer and not useful in a diff or native package.
 <code>dpkg-source</code> will automatically exclude these if it is passed
 <code>-I</code> or <code>-i</code> for native and non-native packages respectively.
See-Also: dpkg-source(1)
