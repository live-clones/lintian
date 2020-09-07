Tag: depends-exclusively-on-makedev
Severity: warning
Check: fields/package-relations
Explanation: This package depends on makedev without a udev alternative. This
 probably means that it doesn't have udev rules and relies on makedev to
 create devices, which won't work if udev is installed and running.
 Alternatively, it may mean that there are udev rules, but udev was not
 added as an alternative to the makedev dependency.
