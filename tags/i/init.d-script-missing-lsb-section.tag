Tag: init.d-script-missing-lsb-section
Severity: warning
Check: init-d
See-Also: https://wiki.debian.org/LSBInitScripts
Explanation: This <code>/etc/init.d</code> script does not have an LSB keyword
 section (or the <code>### BEGIN INIT INFO</code> tag is incorrect). This
 section provides description and runlevel information in a standard
 format and provides dependency information that can be used to
 parallelize the boot process. Please consider adding it.
