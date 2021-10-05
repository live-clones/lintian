Tag: package-supports-alternative-init-but-no-init.d-script
Severity: info
Check: init-d
See-Also: policy 9.11
Explanation: The package provides daemon, but contains no init.d script
 Packages that provide services (daemons), like cron daemon or web servers,
 may provide init.d script for starting that services with sysvinit.
 Optionally, packages can also provide integration with alternative init
 systems.
 .
 Package in question provides integration with some alternative init system,
 but corresponding init.d script is absent.
 .
 See <code>init-d-script</code>(5) for one of possible ways writing init.d scripts.
