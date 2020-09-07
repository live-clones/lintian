Tag: non-debug-file-in-debug-package
Severity: error
Check: files/debug-packages
Explanation: This auto-generated package (eg. <code>-dbgsym</code>) contains the
 specified file that is not a <code>.debug</code> file.
 .
 This may be due to the upstream build system miscalculating
 installation paths.
See-Also: Bug#958945
