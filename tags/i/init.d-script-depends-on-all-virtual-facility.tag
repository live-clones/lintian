Tag: init.d-script-depends-on-all-virtual-facility
Severity: error
Check: init-d
Explanation: The given init script declares a dependency on the virtual
 facility "$all". This virtual facility is reserved for very special
 cases, that work specifically with init system.
 .
 Regular services should not use this facility.
See-Also: https://wiki.debian.org/LSBInitScripts
