Tag: doc-base-document-field-ends-in-whitespace
Severity: error
Check: menus
Explanation: The <code>Document</code> field in a <code>doc-base</code>
 file should not end in whitespace. Versions of <code>doc-base</code> as
 recent as 0.8.5 cannot deal gracefully with such fields.
 .
 Also, Ddebhelper versions 5.0.57 or earlier may create files that end in
 whitespace when such files are installed.
