Tag: loads-obsolete-confmodule
Severity: warning
Check: debian/debconf
Explanation: The maintainer script uses an obsolete name for a debconf confmodule.
 Shell scripts should source <code>/usr/share/debconf/confmodule</code>, while
 Perl scripts should use <code>Debconf::Client::ConfModule</code>.
See-Also: debconf-devel(7)
