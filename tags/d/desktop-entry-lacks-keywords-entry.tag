Tag: desktop-entry-lacks-keywords-entry
Severity: info
Check: menu-format
Explanation: This .desktop file does either not contain a "Keywords" entry or it does
 not contain any keywords not already present in the "Name" or
 "GenericName" entries.
 .
 .desktop files are organized in key/value pairs (similar to .ini files).
 "Keywords" is the name of the entry/key in the .desktop file containing
 keywords relevant for this .desktop file.
 .
 The desktop-file-validate tool in the desktop-file-utils package is
 useful for checking the syntax of desktop entries.
See-Also: https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s06.html,
 Bug#693918, https://wiki.gnome.org/Initiatives/GnomeGoals/DesktopFileKeywords
