Tag: debian-rules-invalid-build-profile-nodocs
Severity: warning
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package uses the
 invalid Build-Profile name <code>nodocs</code>. It should instead use the valid
 one named <code>nodoc</code>.
See-Also: https://wiki.debian.org/BuildProfileSpec#Registered_profile_names
