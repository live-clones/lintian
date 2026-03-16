Tag: missing-systemd-service-for-init.d-rcS-script
Severity: error
Check: systemd
See-Also: https://wiki.debian.org/Teams/pkg-systemd/rcSMigration
Explanation: The rcS init.d script has no systemd equivalent.
 .
 As of version 260, systemd no longer supports SysV compatibility mode. As
 such, this package will no longer work for systems which use systemd as the
 init system. Therefore, services provided by this package will not start in
 the boot sequence for these machines.
Renamed-From:
 systemd-no-service-for-init-rcS-script
