Tag: debconf-is-not-a-registry
Severity: warning
Check: debian/debconf
Explanation: In the Unix tradition, Debian packages should have human-readable and
 human-editable configuration files. This package uses debconf commands
 outside its maintainer scripts, which often indicates that it is taking
 configuration information directly from the debconf database. Typically,
 packages should use debconf-supplied information to generate
 configuration files, and -- to avoid losing configuration information on
 upgrades -- should parse these configuration files in the <code>config</code>
 script if it is necessary to ask the user for changes.
 .
 Some standalone programs may legitimately use debconf to prompt the user
 for questions. If you maintain a package containing such a program,
 please install an override. Other exceptions to this check include
 configuration scripts called from the package's post-installation script.
See-Also: devref 6.5.1, debconf-devel(7)
