Tag: missing-systemd-service-for-init.d-rcS-script
Severity: error
Check: systemd
See-Also: https://wiki.debian.org/Teams/pkg-systemd/rcSMigration
Explanation: The rcS init.d script has no systemd equivalent.
 .
 The package will not work for systems which use systemd as the
 init system and hence will not start in the boot sequence, as
 systemd no longer supports SysV compatibility mode.
Renamed-From:
 systemd-no-service-for-init-rcS-script
