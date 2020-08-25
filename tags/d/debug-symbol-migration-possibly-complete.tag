Tag: debug-symbol-migration-possibly-complete
Severity: pedantic
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package has a call to
 <code>dh&lowbar;strip(1)</code> with the specified <code>--dbgsym-migration</code> or
 <code>--ddeb-migration</code> argument.
 .
 Such arguments are used to migrate packages to use automatic debug
 symbols, which first became available in December 2015.
 .
 If this command was added to the <code>debian/rules</code> that was
 included in the current stable release of Debian then it can possibly
 be removed.
 .
 However, if the command was added later (and/or the package was not
 included in stretch) please wait until it has been included in a stable
 release before removing it.
See-Also: dh_strip(1), https://wiki.debian.org/AutomaticDebugPackages
