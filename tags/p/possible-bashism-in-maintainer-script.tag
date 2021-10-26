Tag: possible-bashism-in-maintainer-script
Severity: warning
Check: shell/non-posix/bash-centric
Explanation: This script is marked as running under <code>/bin/sh</code>, but it seems
 to use a feature found in bash but not in the SUSv3 or POSIX shell
 specification.
 .
 Some examples are:
 .
 - <code>==</code> in a test, it should use <code>=</code> instead
 - <code>read</code> without a variable in the argument
 - <code>function</code> to define a function
 - <code>source</code> instead of <code>.</code>
 - <code>. command args</code>, passing arguments to commands via <code>source</code> is not supported
 - <code>{foo,bar}</code> instead of <code>foo bar</code>
 - <code>[[ test ]]</code> instead of <code>[ test ]</code> (requires a Korn shell)
 - <code>type</code> instead of <code>which</code> or <code>command -v</code>
See-Also:
 policy 10.4
