Tag: su-to-root-with-usr-sbin
Severity: warning
Check: menu-format
Explanation: The menu item or desktop file command uses su-to-root as
 /usr/sbin/su-to-root. Since sarge su-to-root is located in /usr/bin and
 /usr/sbin/su-to-root is only a compatibility symlink that may get dropped
 in the future.
 .
 Since su-to-root is now located in /usr/bin you can use it without
 absolute path now.
