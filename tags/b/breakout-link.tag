Tag: breakout-link
Severity: warning
Check: files/hierarchy/links
Explanation: The named link is in <code>/usr/lib</code> and points to higher
 location in the file system, or traverses through one.
 .
 At least for <code>/usr/lib</code>, it is usually an error and may
 confuse some tools.
 .
 To escape this check, links in /usr/lib must point to targets
 in the same directory or a subdirectory thereof.
 .
 Lateral connections to the same level in /usr/lib are not allowed
 if they traverse through a higher directory, because in a typical
 multi-lib layout that might point to another architecture.
See-Also: Bug#243158
