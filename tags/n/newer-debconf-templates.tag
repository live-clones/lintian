Tag: newer-debconf-templates
Severity: warning
Check: debian/po-debconf
Explanation: debconf-updatepo has not been run since the last change to your
 debconf templates.
 .
 You should run debconf-updatepo whenever debconf templates files are
 changed so that translators can be warned that their files are
 outdated.
 .
 This can be ensured by running debconf-updatepo in the 'clean' target
 of <code>debian/rules</code>. PO files will then always be up-to-date when
 building the source package.
