Tag: requires-r-api
Severity: error
Check: languages/r/site-library
Explanation: This package ships a site library for the <code>R</code>
 programming language package but does not declare the
 <code>R</code> API <code>r-api-*N*</code> as a package
 prerequisite.
 .
 With the dh sequencer, please use <code>--buildsystem=R</code> in
 <code>debian/rules</code> and add the substitution variable
 <code>${R:Depends}</code> to the <code>Depends</code> field in
 <code>debian/control</code>.
See-Also: https://wiki.debian.org/Teams/r-pkg-team
