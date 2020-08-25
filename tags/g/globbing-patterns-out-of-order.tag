Tag: globbing-patterns-out-of-order
Severity: warning
Check: debian/copyright/dep5
Explanation: The <code>Files</code> sections in debian/copyright are out of order.
 The relative directory depth should increase from one section to the next.
 That is the general pattern of the specification, with &ast; at the top.
 .
 When sections are in another order, some files may be associated
 with the wrong license.
 .
 Please reorder the sections.
See-Also: Bug#905747,
 https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
