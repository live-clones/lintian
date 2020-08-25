Tag: trailing-slash-for-dpkg-maintscript-helper-symlink_to_dir
Severity: error
Check: scripts
Explanation: The maintainer script seems to call dpkg-maintscript-helper
 symlink&lowbar;to&lowbar;dir with a trailing slash for pathname. This renders the
 package uninstallable.
See-Also: dpkg-maintscript-helper(1)
