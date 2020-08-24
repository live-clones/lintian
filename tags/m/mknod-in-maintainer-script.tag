Tag: mknod-in-maintainer-script
Severity: error
Check: scripts
See-Also: policy 10.6
Explanation: Maintainer scripts must not create device files directly. They
 should call <tt>MAKEDEV</tt> instead.
 .
 If <tt>mknod</tt> is being used to create a FIFO (named pipe), use
 <tt>mkfifo</tt> instead to avoid triggering this tag.
