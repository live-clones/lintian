Tag: non-conf-file-in-modprobe.d
Severity: error
Check: modprobe
See-Also: https://lists.debian.org/debian-devel/2009/03/msg00119.html
Explanation: Files in <code>/etc/modprobe.d</code> should use filenames ending in
 <code>.conf</code>. modprobe silently ignores all files which do not match
 this convention.
 .
 If the file is an example containing only comments, consider installing
 it in another location as files in <code>/etc/modprobe.d</code> are
 read each time modprobe is run (which is often at boot time).
