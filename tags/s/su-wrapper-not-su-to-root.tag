Tag: su-wrapper-not-su-to-root
Severity: warning
Check: menu-format
Explanation: The menu item or desktop file command uses an su wrapper other than
 su-to-root. On Debian systems, please use <code>su-to-root -X</code>, which
 will pick the correct wrapper based on what's installed on the system and
 the current desktop environment. Using su-to-root is also important for
 Live CD systems which need to use sudo rather than su. su-to-root
 permits global configuration to use sudo.
