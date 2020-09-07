Tag: zero-byte-file-in-doc-directory
Severity: warning
Check: documentation
Explanation: The documentation directory for this package contains an empty
 file. This is often due to installing an upstream NEWS or README file
 without realizing it's empty and hence not useful.
 .
 Files in the examples subdirectory are excluded from this check, but
 there are some cases where empty files are legitimate parts of the
 documentation without being examples. In those cases, please add an
 override.
