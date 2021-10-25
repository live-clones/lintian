Tag: no-code-sections
Severity: error
Check: libraries/static/no-code
Explanation:
 The named members of the static library have no usable code sections.
 .
 It happens when shared objects are built with <code>-flto=auto</code> but
 without <code>-ffat-lto-objects</code>. <code>dh_strip</code> strips the
 LTO sections but may leave the static library without any usable code.
See-Also:
 Bug#977596
