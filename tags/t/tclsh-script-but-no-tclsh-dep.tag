Tag: tclsh-script-but-no-tclsh-dep
Severity: error
Check: scripts
Explanation: Packages that include tclsh scripts must depend on the virtual
 package tclsh or, if they require a specific version of tcl, that
 version of tcl.
 .
 In some cases a weaker relationship, such as Suggests or Recommends, will
 be more appropriate.
