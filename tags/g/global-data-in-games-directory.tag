Tag: global-data-in-games-directory
Severity: error
Check: games
Explanation: This package contains files under <code>/usr/share/games</code>, such as
 desktop files, icons, pixmaps, or MIME type entries, that are global
 system data. The user's desktop environment will only check in the
 directories directly under <code>/usr/share</code> and this information
 should be put in the global directory even if it is for games.
 .
 The most common cause of this problem is using a
 <code>--datadir=/usr/share/games</code> argument to configure or an
 equivalent and using the upstream installation rules. These files need
 to be moved into the corresponding directories directly under
 <code>/usr/share</code>.
