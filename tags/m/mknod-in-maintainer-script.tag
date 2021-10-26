Tag: mknod-in-maintainer-script
Severity: error
Check: maintainer-scripts/mknod
Explanation: Maintainer scripts must not create device files directly. They
 should call <code>MAKEDEV</code> instead.
 .
 If <code>mknod</code> is being used to create a FIFO (named pipe), use
 <code>mkfifo</code> instead to avoid triggering this tag.
See-Also:
 policy 10.6
