Tag: absolute-symbolic-link-target-in-source
Severity: warning
Check: files/symbolic-links
Explanation: This symlink in a patched source tree points to an absolute target. It
 happens sometimes when people point toward /dev/null, but that can and should
 be done in the installation package instead. It is no problem there. The
 source package is considered unanchored and should not contain any absolute
 file references.
 .
 Please remove the symbolic link from the source package or point it to a
 a location inside the patched source tree.
