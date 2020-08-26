Tag: ambiguous-paragraph-in-dep5-copyright
Severity: warning
Check: debian/copyright/dep5
See-Also: Bug#652380, https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Explanation: The paragraph has a "License" and a "Copyright" field, but no
 "Files" field. Technically, this is a valid paragraph per the DEP 5
 specification. However, it is mostly likely a mistake.
 .
 If it is a <code>stand-alone license paragraph</code>, the "Copyright"
 field is not needed and should be removed. On the other hand, if it
 is a <code>files paragraph</code>, it is missing the "Files" field.
 .
 Please note that while the "Files" field was optional in some cases
 in some of the earlier draft versions, it is mandatory in *all*
 <code>files paragraphs</code> in the current specification.
 .
 Lintian will attempt to guess what you intended and continue based on
 its guess. If the guess is wrong, you may see spurious tags related
 to this paragraph.
