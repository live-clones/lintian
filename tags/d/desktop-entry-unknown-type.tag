Tag: desktop-entry-unknown-type
Severity: warning
Check: menu-format
Explanation: This desktop entry uses a type that's not one of the currently
 recognized values of "Application", "Link" or "Directory".
 Implementations should ignore any unknown values but it's still likely
 an error if you used something else and this check should be updated if
 any new desktop file types start being used.  Note that case is
 significant.
 .
 The desktop-file-validate tool in the desktop-file-utils package is
 useful for checking the syntax of desktop entries.
See-Also: https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s06.html
