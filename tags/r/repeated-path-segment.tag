Tag: repeated-path-segment
Severity: pedantic
Check: files/hierarchy/path-segments
Explanation: The file is installed into a location that repeats the given
 path segment. An example would be <code>/usr/lib/lib</code> or
 <code>/usr/share/myprogram/share</code>.
 .
 More often than not this is unintended.
See-Also: Bug#950052, Bug#950027
