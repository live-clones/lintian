Tag: invalid-escape-sequence-in-dep5-copyright
Severity: warning
Check: debian/copyright/dep5
See-Also: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Explanation: The only allowed escape sequences are "\&ast;", "\?" and "\\" (without
 quotes) to produce a literal star, question mark and backslash, respectively.
 Without the escaping backslash, the star and question mark take the role of
 globbing operators similar to shell globs which is why they have to be
 escaped. No other escapable characters than "&ast;", "?" and "\" exist.
