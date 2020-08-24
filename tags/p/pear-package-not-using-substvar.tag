Tag: pear-package-not-using-substvar
Severity: info
Check: languages/php/pear
Explanation: The package is a PEAR package but the control file does not use
 ${phppear:summary} or ${phppear:description} in its description fields.
 .
 The substitution variables should be used when the description in the
 PEAR package is suitable and respects best packaging practices.
See-Also: https://www.debian.org/doc/manuals/developers-reference/best-pkging-practices.html#bpp-desc-basics
