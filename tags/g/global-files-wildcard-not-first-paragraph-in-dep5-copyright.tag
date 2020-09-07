Tag: global-files-wildcard-not-first-paragraph-in-dep5-copyright
Severity: warning
Check: debian/copyright/dep5
Explanation: The specified paragraph in the machine readable copyright file references
 all possible files but is not the first paragraph. For example:
 .
  Files: filea
  Copyright: 2009, ...
 .
  Files: &ast;
  Copyright: 2010, ...
 .
 As the paragraphs is matched on a "last match wins" principle, all proceeding
 paragraphs are overridden.
See-Also: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
