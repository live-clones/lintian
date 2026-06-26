Tag: binary-file-built-without-64bit-time-support
Severity: info
Check: binaries/time32
Experimental: yes
Explanation: The listed ELF binary appears to use 32bit wide time variables
 that cannot hold times later than Jan 19 2038.
 .
 Enabling 64bit wide <code>time&lowbar;t</code> can introduce inconsistencies,
 e.g. if a lib is used that uses a <code>time&lowbar;t</code> of different
 size. So converting a package needs careful review e.g. to check if the size
 of <code>time&lowbar;t</code> has an impact on ABI (file formats, prototypes
 for exported functions, network protocols) or if <code>time&lowbar;t</code>
 values are assigned to/from ints. Further libc types that are affected are:
 <code>struct itimerspec</code>,
 <code>struct msqid_ds</code>,
 <code>struct msqid_ds</code>,
 <code>struct ntptimeval</code>,
 <code>struct rusage</code>,
 <code>struct semid_ds</code>,
 <code>struct shmid_ds</code>,
 <code>struct stat</code>,
 <code>struct timespec</code>,
 <code>struct timeval</code>,
 <code>struct timex</code>,
 <code>struct utimbuf</code>.
 .
 So libraries that have an ABI that depends on the size of
 <code>time&lowbar;t</code> either need to be updated to time64 in lockstep
 with all its consumers, or it needs to be expanded to support both 64bit and
 32bit time consumers (like glibc does).
 .
 To actually convert a package to 64bit time support you first have to enable
 large file support because time64 only works in combination with 64bit
 <code>off&lowbar;t</code>.
 .
 To actually enable 64bit <code>time&lowbar;t</code>, you have to define the cpp
 symbol <code>&lowbar;TIME&lowbar;BITS</code> to 64 (i.e. pass
 <code>-D&lowbar;TIME&lowbar;BITS=64 -D&lowbar;LARGEFILE&lowbar;SOURCE
 -D&lowbar;FILE&lowbar;OFFSET&lowbar;BITS=64</code> to the compiler).
 One way to do that is to enable the <code>time64</code>
 feature from the <code>future</code> dpkg-buildflags feature (since dpkg 1.22.0)
 (i.e. <code>export DEB&lowbar;BUILD&lowbar;MAINT&lowbar;OPTIONS = future=+time64</code>).
