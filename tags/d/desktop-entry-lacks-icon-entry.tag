Tag: desktop-entry-lacks-icon-entry
Severity: info
Check: menu-format
Explanation: This .desktop file does not contain an "Icon" entry.
 .
 "Icon" is the name of the file (without the extension) of the icon displayed
 by this .desktop file. The icon is searched in the different icon themes.
 If the name is an absolute path, the given file will be used.
 The icon should be unique enough to help the user to recognise the application.
 .
 The desktop-file-validate tool in the desktop-file-utils package is
 useful for checking the syntax of desktop entries.
See-Also: https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s06.html,
 https://specifications.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html,
 Bug#854132
