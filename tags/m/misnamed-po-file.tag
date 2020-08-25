Tag: misnamed-po-file
Severity: warning
Check: debian/po-debconf
Explanation: The name of this PO file doesn't appear to be a valid language
 code. Any files in <code>debian/po</code> ending in <code>.po</code> will be
 processed as translations by po2debconf for the language code equal to
 the file name without the trailing <code>.po</code>. If the file name does
 not correctly reflect the language of the translation, the translation
 will not be accessible to users of that language.
 .
 If this file isn't actually a PO file, rename it to something that
 doesn't end in <code>.po</code> or move it to another directory so that
 translation merging programs will not be confused.
