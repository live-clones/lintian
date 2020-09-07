Tag: package-depends-on-an-x-font-package
Severity: error
Check: fields/package-relations
Explanation: Packages must not depend on X Window System font packages.
 .
 If one or more of the fonts so packaged are necessary for proper operation
 of the package with which they are associated the font package may be
 Recommended; if the fonts merely provide an enhancement, a Suggests
 relationship may be used.
See-Also: policy 11.8.5
