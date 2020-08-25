Tag: maintainer-script-switches-dir-to-symlink-unsafely
Severity: error
Check: scripts
Experimental: yes
Renamed-From: maintainer-script-may-use-dir_to_symlink_helper
Explanation: The maintainer script apparently change a directory to a symlink
 not using dir&lowbar;to&lowbar;symlink command of dpkg-maintscript-helper, that take
 great care to avoid a lot of problems.
 .
 Please use the dpkg-maintscript-helper dir&lowbar;to&lowbar;symlink command.
See-Also: dpkg-maintscript-helper(1)
