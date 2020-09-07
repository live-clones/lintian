Tag: info-document-missing-dir-entry
Severity: error
Check: documentation/texinfo
Explanation: This info document has no directory entry. This is text between
 START-INFO-DIR-ENTRY and END-INFO-DIR-ENTRY lines which is copied into
 the <code>dir</code> file in <code>/usr/share/info</code> by
 <code>install-info</code>. The best solution is to add lines like:
 .
   @dircategory Software development
   @direntry
   &ast; foo: (foo).               Foo creator and editor
   @end direntry
 .
 to the texinfo source so that the generated info file will contain an
 appropriate entry. You will have to ensure that the build process builds
 new info files rather than using ones built by upstream.
