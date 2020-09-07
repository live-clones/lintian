Tag: package-contains-documentation-outside-usr-share-doc
Severity: info
Check: documentation
Explanation: This package ships a documentation file outside /usr/share/doc
 Documentation files are normally installed inside <code>/usr/share/doc</code>.
 .
 If this file doesn't describe the contents or purpose of the directory
 it is in, please consider moving this file to <code>/usr/share/doc/</code>
 or maybe even removing it. If this file does describe the contents
 or purpose of the directory it is in, please add a lintian override.
