Tag: non-virtual-facility-in-initd-script
Severity: error
Check: init-d
Renamed-From: init.d-script-should-depend-on-virtual-facility
Explanation: The given <code>/etc/init.d</code> script depends on a non-virtual
 facility that should probably be replaced by a virtual facility. For
 example, init scripts should depend on the virtual facility
 <code>$network</code> rather than the facility <code>networking</code>, and the
 virtual facility <code>$named</code> rather than the specific facility
 <code>bind9</code>.
 .
 Properly using virtual facilities allows multiple implementations of the
 same facility and accommodates systems where that specific facility may
 not be enough to provide everything the script expects.
