Tag: zero-byte-executable-in-path
Severity: error
Check: files/names
Explanation: This package installs the specified empty executable file to the
 system's PATH. These files do not do anything and produce no error
 message when run.
 .
 This was likely caused by an error in the package build process.
See-Also: Bug#919341
