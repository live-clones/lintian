Tag: orphaned-package-maintained-in-private-space
Severity: warning
Check: fields/vcs
Explanation:
 This package is orphaned and the specified VCS field points to a private
 space in the &ast;.debian.org infrastructure. The sources are probably not
 accessible to the Quality Assurance (QA) Team, which prepares uploads
 in the interim.
 .
 Please move the source repository to a location in
 <code>https://salsa.debian.org/debian/</code> or <code>https://git.dgit.debian.org/</code>
 or update the specified VCS field if the information is incorrect.
See-Also: Bug#947671
