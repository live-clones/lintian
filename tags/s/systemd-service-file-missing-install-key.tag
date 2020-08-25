Tag: systemd-service-file-missing-install-key
Severity: info
Check: systemd
Explanation: The systemd service file does not contain a <code>WantedBy=</code> or
 <code>RequiredBy=</code> key in its <code>[Install]</code> section.
 .
 Forgetting to add such a line (e.g. <code>WantedBy=multi-user.target</code>)
 results in the service file not being started by default.
See-Also: systemd.unit(5)
