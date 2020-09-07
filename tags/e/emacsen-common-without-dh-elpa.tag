Tag: emacsen-common-without-dh-elpa
Severity: warning
Check: emacs/elpa
Explanation: The package uses the emacsen-common infrastructure but the
 package was not built with dh-elpa. Please consider transitioning
 the package build to use dh-elpa, unless the package is required to
 work with XEmacs.
 .
 dh-elpa centralises the emacsen-common maintscripts, which makes for
 fewer bugs, and significantly easier cross-archive updates to emacsen
 packages.
 .
 In addition, a package built with dh-elpa integrates with the GNU
 Emacs package manager, for a better user experience.
See-Also: dh_elpa(1), dh-make-elpa(1), https://wiki.debian.org/Teams/DebianEmacsenTeam/elpa-hello
