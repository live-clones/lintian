Tag: missing-systemd-service-for-init.d-script
Severity: warning
Check: systemd
Explanation: The specified init.d script has no equivalent systemd service.
 .
 Whilst systemd has a SysV init.d script compatibility mode, providing
 native systemd support has many advantages such as being able to specify
 security hardening features. Moreover, the systemd SysV generator will be
 deprecated in the future.
 .
 Please provide a suitable .service file for this script.
