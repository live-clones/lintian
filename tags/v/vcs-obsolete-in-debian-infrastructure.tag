Tag: vcs-obsolete-in-debian-infrastructure
Severity: warning
Check: fields/vcs
Explanation: The specified Vcs-&ast; field points to an area within the &ast;.debian.org
 infrastructure but refers to a version control system that has been
 deprecated.
 .
 After 1st May 2018, Debian ceased to offer hosting for any version
 control system other than Git and the Alioth service became read-only
 in May 2018. Packages should migrate to Git hosting on
 https://salsa.debian.org.
 .
 For further information about salsa.debian.org, including how to add
 HTTP redirects from alioth, please consult the Debian Wiki.
See-Also: https://lists.debian.org/debian-devel-announce/2017/08/msg00008.html,
 https://wiki.debian.org/Salsa
