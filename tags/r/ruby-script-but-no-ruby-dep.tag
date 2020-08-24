Tag: ruby-script-but-no-ruby-dep
Severity: error
Check: scripts
Explanation: Packages with Ruby scripts must depend on a valid Ruby interpreter.
 Those that have Ruby scripts that run under a specific version of Ruby need a
 dependency on the equivalent version of Ruby.
 .
 If a script in the package uses <tt>#!/usr/bin/ruby</tt>, the package needs a
 dependency on "ruby | ruby-interpreter". This allows users to choose which
 interpreter to use by default. If the package is intended to be used with a
 specific Ruby version, its scripts should use that version directly, such
 as <tt>#!/usr/bin/ruby1.8</tt>
 .
 If a script uses <tt>#!/usr/bin/ruby1.9</tt>, then the package needs a
 dependency on "ruby1.9".
 .
 In some cases a weaker relationship, such as Suggests or Recommends, will
 be more appropriate.
