Tag: file-in-unknown-x11-font-directory
Severity: error
Check: desktop/x11
See-Also: policy 11.8.5
Explanation: Subdirectories of <code>/usr/share/fonts/X11</code> other than
 <code>100dpi</code>, <code>75dpi</code>, <code>misc</code>, <code>Type1</code>, and some
 historic exceptions must be neither created nor used. (The directories
 <code>encodings</code> and <code>util</code>, used by some X Window System
 packages, are also permitted by Lintian.)
