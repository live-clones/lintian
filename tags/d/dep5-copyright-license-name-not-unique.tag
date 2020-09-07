Tag: dep5-copyright-license-name-not-unique
Severity: warning
Check: debian/copyright/dep5
See-Also: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Explanation: This paragraph defines an already defined license.
 .
 According to the specification, short license names are required to be
 unique within a single copyright file.
 .
 This tag could be raised by something like this:
 .
  Files: filea ...
  Copyright: 2009, ...
  License: LGPL-2.1
   This program is free software;
          ...
 .
  Files: fileb ...
  Copyright: 2009, ...
  License: LGPL-2.1
   This program is free software;
   ...
 .
 In this case, you redefine LGPL-2.1 license. You should use
 a stand-alone paragraph or merge the two files (using a single
 paragraph).
