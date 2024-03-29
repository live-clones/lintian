Tag: dir-or-file-in-var-run
Severity: error
Check: files/hierarchy/standard
Explanation: <code>/var/run</code> may be a temporary filesystem, so any directories
 or files needed there must be created dynamically at boot time.
See-Also: debian-policy 9.3.2
