Tag: r-package-not-arch-all
Severity: warning
Check: fields/architecture
Explanation: The package for an <tt>R</tt> language package ships a
 <tt>DESCRIPTION</tt> file that states <tt>NeedsCompilation: No</tt>
 but is not marked <tt>Architecture: all</tt>.
 .
 The package does not require compilation and should be
 architecture-independent.
See-Also: https://cran.r-project.org/doc/manuals/r-devel/R-exts.html
