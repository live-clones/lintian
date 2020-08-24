Tag: directory-in-etc-sv-directory-without-executable-run-script
Severity: error
Check: init.d
Explanation: This package provides the specified directory under
 <tt>/etc/sv</tt> but it does not ship a <tt>run</tt> script under this
 directory.
 .
 Please check that you are installing your <tt>run</tt> script to the
 right location and that has the correct executable permissions.
See-Also: dh_runit(1)
