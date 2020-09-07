Tag: dir-or-file-in-var-lock
Severity: error
Check: files/hierarchy/standard
Explanation: <code>/var/lock</code> may be a temporary filesystem, so any directories
 or files needed there must be created dynamically at boot time.
See-Also: policy 9.3.2
