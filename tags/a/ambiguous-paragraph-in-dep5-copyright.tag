Tag: ambiguous-paragraph-in-dep5-copyright
Severity: warning
Check: debian/copyright/dep5
Explanation: The paragraph has both <code>License</code> and
 <code>Copyright</code> fields, but no <code>Files</code> field. The paragraph
 is technically valid according to the DEP 5 specification, but it is probably
 a mistake.
 .
 If the paragraph is a "stand-alone" license paragraph, the <code>Copyright</code>
 field is not needed. If it is, on the other hand, "files" paragraph, the
 <code>Files</code> field is missing.
 .
 The <code>Files</code> field was at some point optional in some circumstances
 but is now mandatory in all "files" paragraphs.
See-Also:
 Bug#652380,
 https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
