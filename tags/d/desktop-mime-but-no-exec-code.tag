Tag: desktop-mime-but-no-exec-code
Severity: warning
Check: menu-format
Explanation: The named desktop entry indicates support for at least one MIME
 type, but does not provide a code like %f, %F, %u or %U in the <code>Exec</code>
 key.
 .
 If the application can in fact handle files of the given MIME types, the
 <code>menu</code> item should somehow pass those filenames as parameters to the
 executable.
