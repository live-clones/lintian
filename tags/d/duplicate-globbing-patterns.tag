Tag: duplicate-globbing-patterns
Severity: error
Check: debian/copyright/dep5
Explanation: A globbing pattern was used again in <code>debian/copyright</code>.
 It always an error and may indicate confusion about the applicable
 license for the autor or any reader of the file.
 .
 Please remove all but one of the identical globbing patterns.
See-Also: Bug#90574,
 https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
