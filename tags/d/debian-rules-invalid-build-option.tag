Tag: debian-rules-invalid-build-option
Severity: warning
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package tests for an
 invalid <code>DEB_BUILD_OPTIONS</code> setting. It should instead use a valid
 one, as listed in the official list below.
See-Also: https://wiki.debian.org/BuildProfileSpec#Registered_profile_names
