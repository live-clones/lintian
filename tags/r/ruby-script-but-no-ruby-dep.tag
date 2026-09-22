Tag: ruby-script-but-no-ruby-dep
Severity: error
Check: scripts
Explanation: Packages with Ruby scripts must depend on a valid Ruby interpreter.
 If any script uses <code>#!/usr/bin/ruby</code>, the package
 should declare <code>ruby</code> as a prerequisite.
 .
 In some cases, a weaker relationship like <code>Suggests</code> or
 <code>Recommends</code> is more appropriate.
 .
 If the script is not meant to be executable, but meant to be consumed by other
 programs or are reserved for specific use, the script should be made non-executable.
