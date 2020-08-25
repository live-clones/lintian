Tag: systemd-service-file-refers-to-unusual-wantedby-target
Severity: warning
Check: systemd
Explanation: The specified systemd service file declares an unusual
 <code>WantedBy=</code> relationship.
 .
 Most services that want to be started automatically at boot should use
 <code>WantedBy=multi-user.target</code> or <code>WantedBy=graphical.target</code>.
 Services that want to be started in rescue or single-user mode should
 instead use <code>WantedBy=sysinit.target</code>
See-Also: https://wiki.debian.org/Teams/pkg-systemd/rcSMigration
