Tag: missing-license-paragraph-in-dep5-copyright
Severity: warning
Check: debian/copyright/dep5
Explanation: The <code>Files</code> paragraph in the machine readable copyright file
 references a license for which no stand-alone <code>License</code> paragraph
 exists.
 .
 Sometimes this tag appears because of incorrect ordering. Stand-alone
 <code>License</code> paragraphs must appear *after* all <code>Files</code>
 paragraphs.
See-Also: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/,
 Bug#959067
