Tag: missing-license-paragraph-in-dep5-copyright
Severity: warning
Check: debian/copyright/dep5
Explanation: The <tt>Files</tt> paragraph in the machine readable copyright file
 references a license for which no stand-alone <tt>License</tt> paragraph
 exists.
 .
 Sometimes this tag appears because of incorrect ordering. Stand-alone
 <tt>License</tt> paragraphs must appear <em>after</em> all <tt>Files</tt>
 paragraphs.
See-Also: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/,
 Bug#959067
