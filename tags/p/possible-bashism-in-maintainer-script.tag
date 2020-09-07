Tag: possible-bashism-in-maintainer-script
Severity: warning
Check: scripts
See-Also: policy 10.4
Explanation: This script is marked as running under <code>/bin/sh</code>, but it seems
 to use a feature found in bash but not in the SUSv3 or POSIX shell
 specification.
 .
 Examples:
  '==' in a test, it should use '=' instead
  'read' without a variable in the argument
  'function' to define a function
  'source' instead of '.'
  '. command args', passing arguments to commands via 'source' is not supported
  '{foo,bar}' instead of 'foo bar'
  '[[ test ]]' instead of '[ test ]' (requires a Korn shell)
  'type' instead of 'which' or 'command -v'
