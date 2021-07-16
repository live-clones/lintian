Tag: ruby-script-but-no-ruby-dep
Severity: error
Check: scripts
Explanation: Packages with Ruby scripts must depend on a valid Ruby interpreter.
 If a script in the package uses <code>#!/usr/bin/ruby</code>, the package
 needs a dependency on "ruby".
 .
 In some cases a weaker relationship, such as Suggests or Recommends, will
 be more appropriate.
