Tag: file-in-discouraged-x11-font-directory
Severity: warning
Check: desktop/x11
See-Also: policy 11.8.5
Explanation: For historical reasons, use of <code>PEX</code>, <code>CID</code>,
 <code>Speedo</code>, and <code>cyrillic</code> subdirectories of
 <code>/usr/share/fonts/X11</code> are permitted, but installation of files
 into these directories is discouraged. Support for the first three font
 types is deprecated or no longer available, and Cyrillic fonts should use
 the normal font directories where possible.
