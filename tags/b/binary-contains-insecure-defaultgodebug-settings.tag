Tag: binary-contains-insecure-defaultgodebug-settings
Severity: pedantic
Check: languages/golang/default-godebug
Explanation: The binary contains legacy or insecure <code>DefaultGODEBUG</code>
 variable settings.
 .
 Modern Go versions allow developers to force legacy (and potentially
 insecure) behaviors using //go:debug directives or <code>GODEBUG</code> settings.
 .
 While these are sometimes necessary for temporary compatibility, they
 can introduce security vulnerabilities, disable critical fixes, or
 compromise build reproducibility.
