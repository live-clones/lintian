Tag: systemd-diversion
Severity: error
Check: maintainer-scripts/diversion
Explanation: A diversion is being added for a systemd configuration file.
 Diversions must not be used for systemd configuration files. Instead please make
 use of the native override/drop-in mechanisms. This applies not only to the
 system and service manager, but also to udev, tmpfiles.d, sysusers.d and other
 tools from the systemd project. For information on how to use overrides and
 drop-ins, consult the apposite tool's documentation.
See-Also:
 debian-policy 3.9,
 https://www.freedesktop.org/software/systemd/man/systemd.unit.html#Description,
 https://www.freedesktop.org/software/systemd/man/systemd-system.conf.html,
 https://www.freedesktop.org/software/systemd/man/udev.html#Rules%20Files,
 https://www.freedesktop.org/software/systemd/man/tmpfiles.d.html#Configuration%20Directories%20and%20Precedence,
 https://www.freedesktop.org/software/systemd/man/modules-load.d.html#Configuration%20Format,
 https://www.freedesktop.org/software/systemd/man/sysusers.d.html#Configuration%20Directories%20and%20Precedence
