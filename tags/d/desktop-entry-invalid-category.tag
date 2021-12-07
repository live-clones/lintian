Tag: desktop-entry-invalid-category
Severity: warning
Check: menu-format
Explanation: This <code>desktop</code> entry shows a category that is not
 among the registered "main" or "additional" categories in the FreeDesktop
 specification.
 .
 The values are case-sensitive. Whitespace is only allowed just before and
 after the equals sign in the <code>Category</code> key, and nowhere else.
 .
 The <code>desktop-file-validate</code> tool in the
 <code>desktop-file-utils</code> package is useful when checking the syntax
 of desktop entries.
See-Also:
 https://specifications.freedesktop.org/menu-spec/latest/apa.html
