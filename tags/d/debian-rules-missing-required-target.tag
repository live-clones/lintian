Tag: debian-rules-missing-required-target
Severity: error
Check: debian/rules
See-Also: policy 4.9
Explanation: The <code>debian/rules</code> file for this package does not provide one
 of the required targets. All of build, binary, binary-arch,
 binary-indep, and clean must be provided, even if they don't do anything
 for this package.
