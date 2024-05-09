Tag: debian-rules-invalid-build-option-nodocs
Severity: warning
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package tests for the
 invalid <code>DEB_BUILD_OPTIONS</code> setting <code>nodocs</code>. It should
 instead use the valid one named <code>nodoc</code>.
See-Also: https://wiki.debian.org/BuildProfileSpec#Registered_profile_names
