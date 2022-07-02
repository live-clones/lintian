Tag: desktop-entry-lacks-icon-entry
Severity: info
Check: menu-format
Explanation: This <code>.desktop</code> file does not contain an <code>Icon</code>
 entry.
 .
 The <code>Icon</code> field should contain the name of the icon file, without the
 extension, that is displayed. The different icon themes are searched to locate it.
 For absolute paths, the name given will be used. The icon should be sufficiently
 unique so that the user can recognize the application.
 .
 The <code>desktop-file-validate</code> tool in the <code>desktop-file-utils</code>
 package may be useful for checking the syntax of desktop entries.
See-Also:
 https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s06.html,
 https://specifications.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html,
 Bug#854132
