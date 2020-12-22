Tag: init.d-script-depends-on-unknown-virtual-facility
Severity: error
Check: init-d
Explanation: The given init script declares a dependency on a virtual facility
 that is not known to be provided by any init.d script in the archive.
 If the dependency cannot be satisfied upon the package's
 installation, insserv will refuse the activation of the init.d script.
See-Also: https://wiki.debian.org/LSBInitScripts
