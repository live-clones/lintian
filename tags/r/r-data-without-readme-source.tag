Tag: r-data-without-readme-source
Severity: error
Check: languages/r
Explanation: Many modules packaged for the R Project for Statistical Computing contain
 data files with names as &ast;.rda, &ast;.Rda, &ast;.rdata, &ast;.Rdata, etc.
 .
 When such files exist, the FTP masters expect them to be explained in
 debian/README.source, which this package is missing.
 .
 Please add a README.source documenting the origins of these files.
See-Also: https://lists.debian.org/debian-devel/2013/09/msg00332.html
