Tag: init.d-script-needs-depends-on-lsb-base
Severity: error
Check: init-d
Explanation: The given init script sources the <code>/lib/lsb/init-functions</code> utility
 functions without declaring the corresponding dependency on lsb-base.
 .
 This dependency is not required for packages that ship a native service file.
