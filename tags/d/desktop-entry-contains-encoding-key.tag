Tag: desktop-entry-contains-encoding-key
Severity: info
Check: menu-format
Explanation: The <code>Encoding</code> key is deprecated in the FreeDesktop
 standard. Instead, all strings must now be encoded in UTF-8. This desktop entry
 specifies an <code>Encoding</code> of <code>UTF-8</code>. It is harmless but can
 be dropped.
 .
 The <code>desktop-file-validate</code> tool in the <code>desktop-file-utils</code>
 package may be useful for checking the syntax of desktop entries.
See-Also:
 https://specifications.freedesktop.org/desktop-entry-spec/latest/apc.html
