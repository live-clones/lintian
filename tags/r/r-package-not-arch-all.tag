Tag: r-package-not-arch-all
Severity: warning
Check: languages/r/architecture
Explanation: The package for an <code>R</code> language package ships a
 <code>DESCRIPTION</code> file that states <code>NeedsCompilation: No</code>
 but is not marked <code>Architecture: all</code>.
 .
 The package does not require compilation and should be
 architecture-independent.
See-Also: https://cran.r-project.org/doc/manuals/r-devel/R-exts.html
