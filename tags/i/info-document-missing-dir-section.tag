Tag: info-document-missing-dir-section
Severity: error
Check: documentation/texinfo
Explanation: This info document has no INFO-DIR-SECTION line.
 <code>install-info</code> will be unable to determine the section into which
 this info page should be put. The best solution is to add a line like:
 .
   @dircategory Software development
 .
 to the texinfo source so that the generated info file will contain a
 section. See <code>/usr/share/info/dir</code> for sections to choose from.
 You will have to ensure that the build process builds new info files
 rather than using ones built by upstream.
