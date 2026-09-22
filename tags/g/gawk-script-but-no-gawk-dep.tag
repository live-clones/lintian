Tag: gawk-script-but-no-gawk-dep
Severity: error
Check: scripts
Explanation: Packages that use gawk scripts must depend on the gawk package.
 If they don't need gawk-specific features, and can just as easily work
 with mawk, then they should be awk scripts instead.
 .
 In some cases a weaker relationship, such as Suggests or Recommends, will
 be more appropriate.
 .
 If the script is not meant to be executable, but meant to be consumed by other
 programs or are reserved for specific use, the script should be made non-executable.
