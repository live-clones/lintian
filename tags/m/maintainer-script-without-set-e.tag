Tag: maintainer-script-without-set-e
Severity: pedantic
Check: scripts
See-Also: policy 10.4
Explanation: The maintainer script passes <code>-e</code> to the shell on the
 <code>#!</code> line rather than using <code>set -e</code> in the body of the
 script. This is fine for normal operation, but if the script is run by
 hand with <code>sh /path/to/script</code> (common in debugging), <code>-e</code>
 will not be in effect. It's therefore better to use <code>set -e</code> in
 the body of the script.
