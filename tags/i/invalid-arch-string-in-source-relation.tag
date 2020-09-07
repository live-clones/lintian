Tag: invalid-arch-string-in-source-relation
Severity: error
Check: fields/package-relations
See-Also: policy 5.6.8
Explanation: The architecture string in the source relation includes an unknown
 architecture. This may be a typo, or it may be an architecture that dpkg
 doesn't know about yet. A common problem is incorrectly separating
 architectures with a comma, such as <code>[i386, m68k]</code>. Architectures
 are separated by spaces; this should instead be <code>[i386 m68k]</code>.
