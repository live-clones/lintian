Tag: file-name-ends-in-whitespace
Severity: warning
Check: files/names
Explanation: This package installs a file or directory whose name ends in
 whitespace. This might be intentional but it's normally a mistake. If
 it is intentional, add a Lintian override.
 .
 One possible cause is using Debhelper 5.0.57 or earlier to install a
 <code>doc-base</code> file with a <code>Document</code> field that ends
 in whitespace.
