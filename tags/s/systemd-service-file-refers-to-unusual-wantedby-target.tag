Tag: systemd-service-file-refers-to-unusual-wantedby-target
Severity: warning
Check: systemd
Explanation: The specified systemd service file declares an unusual
 <tt>WantedBy=</tt> relationship.
 .
 Most services that want to be started automatically at boot should use
 <tt>WantedBy=multi-user.target</tt> or <tt>WantedBy=graphical.target</tt>.
 Services that want to be started in rescue or single-user mode should
 instead use <tt>WantedBy=sysinit.target</tt>
See-Also: https://wiki.debian.org/Teams/pkg-systemd/rcSMigration
