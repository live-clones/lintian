Tag: loads-obsolete-confmodule
Severity: warning
Check: debian/debconf
Explanation: The maintainer script uses an obsolete name for a debconf confmodule.
 Shell scripts should source <tt>/usr/share/debconf/confmodule</tt>, while
 Perl scripts should use <tt>Debconf::Client::ConfModule</tt>.
See-Also: debconf-devel(7)
