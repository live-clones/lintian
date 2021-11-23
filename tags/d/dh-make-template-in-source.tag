Tag: dh-make-template-in-source
Severity: warning
Check: dh-make/template
Explanation: The named file looks like a <code>dh&lowbar;make</code> template.
 .
 Source files like <code>debian/&ast;.ex</code> or <code>debian/ex.&ast;</code>
 were usually installed by <code>dh&lowbar;make</code>. They are meant to be
 renamed after they were adapted by the maintainer.
 .
 Unused templates should be removed.
