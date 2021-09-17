Tag: invalid-profile-name-in-source-relation
Severity: error
Check: fields/package-relations
Explanation: The restriction formula in the source relation includes an unknown build
 profile. The only allowed build profiles are
 "cross",
 "nobiarch",
 "nocheck",
 "nocil",
 "nodoc",
 "nogolang",
 "noguile",
 "noinsttest",
 "nojava",
 "nolua",
 "noocaml",
 "noperl",
 "nopython",
 "noruby",
 "noudeb",
 "nowasm",
 "nowindows",
 "stage1",
 "stage2"
 and "pkg.*srcpkg*.*anything*".
See-Also: https://wiki.debian.org/BuildProfileSpec#Registered_profile_names
