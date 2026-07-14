Tag: xs-go-import-path-differs-from-module-path
Severity: pedantic
Check: languages/golang/import-path
Explanation: This Golang source declares a <code>XS-Go-Import-Path</code>
 field in the <code>debian/control</code> file that is different from
 the one mentioned in source <code>go.mod</code>.
 .
 With module-aware builds, the mismatch can cause problems with dependency
 resolution.
