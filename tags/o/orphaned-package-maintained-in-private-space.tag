Tag: orphaned-package-maintained-in-private-space
Severity: warning
Check: fields/vcs
Explanation:
 This package is orphaned and the specified VCS field points to a private
 space in the *.debian.org infrastructure. The sources are probably not
 accessible to the Quality Assurance (QA) Team, which prepares uploads
 in the interim.
 .
 Please move the source repository to a location in
 <tt>https://salsa.debian.org/debian/</tt> or <tt>https://git.dgit.debian.org/</tt>
 or update the specified VCS field if the information is incorrect.
See-Also: #947671
