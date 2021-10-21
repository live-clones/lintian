Tag: statically-linked-binary
Severity: error
Check: binaries/static
Explanation: The package installs a statically linked binary or object file.
 .
 Usually this is a bug. Otherwise, please add an override if your package
 is an exception. Binaries named &ast;-static and &ast;.static are automatically
 excluded, as are any binaries in packages named &ast;-static.
