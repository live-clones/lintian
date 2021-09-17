Tag: directory-in-etc-sv-directory-without-executable-run-script
Severity: error
Check: init-d
Explanation: This package provides the specified directory under
 <code>/etc/sv</code> but it does not ship a <code>run</code> script under this
 directory.
 .
 Please check that you are installing your <code>run</code> script to the
 right location and that has the correct executable permissions.
See-Also: dh_runit(1)
