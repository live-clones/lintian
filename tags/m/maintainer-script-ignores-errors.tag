Tag: maintainer-script-ignores-errors
Severity: warning
Check: scripts
See-Also: policy 10.4
Explanation: The maintainer script doesn't seem to set the <code>-e</code> flag which
 ensures that the script's execution is aborted when any executed command
 fails.
