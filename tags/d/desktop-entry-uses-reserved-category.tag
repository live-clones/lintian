Tag: desktop-entry-uses-reserved-category
Severity: warning
Check: menu-format
Explanation: This desktop entry includes a Reserved Category, one which has a
 desktop-specific meaning that has not yet been standardized, but does not
 include an OnlyShowIn key. Desktop entries using a Reserved Category
 must include an OnlyShowIn key limiting the entry to those environments
 that support the category.
 .
 The desktop-file-validate tool in the desktop-file-utils package is
 useful for checking the syntax of desktop entries.
See-Also: https://specifications.freedesktop.org/menu-spec/latest/apa.html
