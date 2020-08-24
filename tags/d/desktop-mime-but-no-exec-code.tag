Tag: desktop-mime-but-no-exec-code
Severity: warning
Check: menu-format
Explanation: The desktop entry lists support for at least one mime type, but does not
 provide codes like %f, %F, %u or %U for the Exec key.
 .
 If the application can indeed handle files of the listed mime types, it should
 specify a way to pass the filenames as parameters.
