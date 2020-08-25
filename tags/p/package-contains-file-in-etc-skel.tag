Tag: package-contains-file-in-etc-skel
Severity: error
Check: files/names
Explanation: This package ships the specified file under <code>/etc/skel</code>. Files
 in this directory are copied into new user accounts by <code>adduser(8)</code>.
 .
 However, <code>/etc/skel</code> should be empty as possible as there is no
 mechanism for ensuring files are copied into the accounts of existing
 users when the package is installed.
 .
 Please remove the installation of this file, ensuring this package
 can automatically create them or can otherwise function without them.
See-Also: policy 10.7.5
