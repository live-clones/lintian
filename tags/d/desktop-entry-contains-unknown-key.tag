Tag: desktop-entry-contains-unknown-key
Severity: warning
Check: menu-format
Explanation: The key on this line of the <code>desktop</code> entry is not listed
 as being defined by the FreeDesktop specification. It is also not one of the legacy
 KDE keywords and does not begin with <code>X-</code>.
 .
 The key may have been misspelled.
 .
 The <code>desktop-file-validate</code> tool in the <code>desktop-file-utils</code>
 package may be useful when checking the syntax of <code>desktop</code> entries.
See-Also:
 https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s06.html
