# Imported from pkg-perl-tools
Tag: libmodule-build-perl-needs-to-be-in-build-depends
Severity: error
Check: fields/package-relations
Experimental: yes
Explanation: libmodule-build-perl needs to be in <code>Build-Depends</code>, not in
 Build-Depends-Indep, since it's used in the clean target.
