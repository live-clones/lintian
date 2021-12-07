Tag: desktop-entry-lacks-keywords-entry
Severity: info
Check: menu-format
Explanation: This <code>.desktop</code> file is either missing a <code>Keywords</code>
 entry, or it does not contain keywords above and beyond those already present in the
 <code>Name</code> or <code>GenericName</code> entries.
 .
 The <code>Keywords</code> field is intended to show keywords relevant for a
 <code>.desktop</code> file.
 .
 Desktop files are organized in key-value pairs and are similar to INI files.
 .
 The <code>desktop-file-validate</code> tool in the <code>desktop-file-utils</code>
 package may be useful when checking the syntax of desktop entries.
See-Also:
 https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s06.html,
 Bug#693918,
 https://wiki.gnome.org/Initiatives/GnomeGoals/DesktopFileKeywords
