Tag: mawk-script-but-no-mawk-dep
Severity: error
Check: scripts
Explanation: Packages that use mawk scripts must depend on the mawk package.
 If they don't need mawk-specific features, and can just as easily work
 with gawk, then they should be awk scripts instead.
 .
 In some cases a weaker relationship, such as Suggests or Recommends, will
 be more appropriate.
