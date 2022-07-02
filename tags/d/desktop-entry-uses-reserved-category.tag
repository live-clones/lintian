Tag: desktop-entry-uses-reserved-category
Severity: warning
Check: menu-format
Explanation: This <code>desktop</code> entry uses a <code>Reserved Category</code>
 as explained below, but does not include an <code>OnlyShowIn</code> key.
 .
 Reserved categories like <code>Screensaver</code>, <code>TrayIcon</code>,
 <code>Applet</code> or <code>Shell</code> have a desktop-specific meaning
 but have not been standardized yet. Desktop entry files that use such a
 reserved category must also include an <code>OnlyShowIn</code> key to limit
 the entry to environments that support the category.
 .
 The <code>desktop-file-validate</code> tool in the <code>desktop-file-utils</code>
 package may be useful when checking the syntax of <code>desktop</code> entries.
See-Also:
 https://specifications.freedesktop.org/menu-spec/latest/apas03.html
