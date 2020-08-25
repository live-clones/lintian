Tag: package-installs-deprecated-upstart-configuration
Severity: warning
Check: files/init
Explanation: The package installs files into the <code>/etc/init</code>
 directory which is used by Upstart, a replacement for the <code>/sbin/init</code>
 daemon which handles starting of tasks and services during boot, etc.
 .
 However, Upstart was removed in Debian "stretch" and these files are thus no
 longer useful and should be removed.
