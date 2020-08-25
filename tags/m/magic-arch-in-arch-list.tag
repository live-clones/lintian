Tag: magic-arch-in-arch-list
Severity: error
Check: fields/architecture
Explanation: The special architecture value "any" only makes sense if it occurs
 alone or (in a &ast;.dsc file) together with "all". The value "all" may
 appear together with other architectures in a &ast;.dsc file but must
 occur alone if used in a binary package.
See-Also: policy 5.6.8, Bug#626775
