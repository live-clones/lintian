Tag: init.d-script-provides-virtual-facility
Severity: warning
Check: init-d
Explanation: This <code>/etc/init.d</code> script indicates in its LSB headers that
 it provides a virtual facility, denoted by the dollar sign in front of
 the name.
 .
 This is not the correct way to provide a virtual facility. Instead, the
 package should include a file in <code>/etc/insserv.conf.d</code>, usually
 named after the package, containing:
 .
  $virtual&lowbar;facility&lowbar;name +init-script-name
 .
 to declare that the named init script provides the named virtual
 facility.
See-Also: https://wiki.debian.org/LSBInitScripts/DebianVirtualFacilities
