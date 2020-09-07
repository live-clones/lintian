Tag: mknod-in-maintainer-script
Severity: error
Check: scripts
See-Also: policy 10.6
Explanation: Maintainer scripts must not create device files directly. They
 should call <code>MAKEDEV</code> instead.
 .
 If <code>mknod</code> is being used to create a FIFO (named pipe), use
 <code>mkfifo</code> instead to avoid triggering this tag.
