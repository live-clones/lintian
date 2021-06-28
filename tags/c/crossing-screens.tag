Tag: crossing-screens
Severity: error
Show-Always: yes
Check: lintian
Explanation: Two or more general screens that mask some tags for entire
 families of packages masked the same tag. Exemptions are supposed to be
 decisive, reliable and rare.
 .
 Screens work a little bit like overrides, except they were authored by
 fellow maintainers who wished to address general issues in larger
 families of packages.
 .
 Your package provoked a tag that was subsequently suppressed by two or
 more of those screens. They are not supposed to intersect.
 .
 The context shows the supressed tag name and the bugs that originally
 gave rise to the screens. They probably explain why the exemptions were
 granted.
 .
 There is nothing you can do about this tag other than contact the
 requestors of the screens (or the Lintian maintainers). The screens
 are misaligned and must be reconfigured.
