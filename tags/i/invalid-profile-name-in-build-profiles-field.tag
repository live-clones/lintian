Tag: invalid-profile-name-in-build-profiles-field
Severity: error
Check: debian/control/field/build-profiles
Explanation: The restriction formula in the <code>Build-Profiles</code> field
 includes an unknown build profile. The only allowed build profiles are:
 .
 - <code>cross</code>
 - <code>nobiarch</code>
 - <code>nocheck</code>
 - <code>nocil</code>
 - <code>nodoc</code>
 - <code>nogolang</code>
 - <code>noguile</code>
 - <code>noinsttest</code>
 - <code>nojava</code>
 - <code>nolua</code>
 - <code>noocaml</code>
 - <code>noperl</code>
 - <code>nopython</code>
 - <code>noruby</code>
 - <code>noudeb</code>
 - <code>nowasm</code>
 - <code>nowindows</code>
 - <code>stage1</code>
 - <code>stage2</code>
 - <code>pkg.&ast;srcpkg&ast;.&ast;anything&ast;</code>
See-Also:
 https://wiki.debian.org/BuildProfileSpec#Registered_profile_names
