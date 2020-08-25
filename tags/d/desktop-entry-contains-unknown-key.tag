Tag: desktop-entry-contains-unknown-key
Severity: warning
Check: menu-format
Explanation: The key on this line of the desktop entry is not one of the standard
 keys defined in the FreeDesktop specification, not one of the legacy KDE
 keywords, and one that does not begin with <code>X-</code>. It's most likely
 that the key was misspelled.
 .
 The desktop-file-validate tool in the desktop-file-utils package is
 useful for checking the syntax of desktop entries.
See-Also: https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s06.html
