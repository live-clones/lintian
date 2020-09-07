Tag: duplicate-conffile
Severity: error
Check: conffiles
Explanation: The file is listed more than once in your <code>debian/conffiles</code> file.
 Usually, this is because debhelper (dh&lowbar;installdeb, compat level 3 or higher)
 will add any files in your package located in /etc automatically to the list
 of conffiles, so if you do that manually too, you'll get duplicates.
