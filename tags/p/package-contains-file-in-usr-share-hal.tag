Tag: package-contains-file-in-usr-share-hal
Severity: warning
Check: files/names
Explanation: This package installs the specified file under
 <code>/usr/share/hal/</code> but this directory is no longer looked at
 by any package in Debian since the removal of the <code>hal</code> package
 in 2014.
 .
 Please remove or otherwise prevent the installation of this file.
