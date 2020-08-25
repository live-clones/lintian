Tag: maintainer-script-needs-depends-on-xfonts-utils
Severity: warning
Check: scripts
Explanation: This script calls a utility provided by the xfonts-utils package
 but does not depend or pre-depend on this package.
 .
 Packages that call update-fonts-scale, update-fonts-dir (etc.) need to
 depend on xfonts-utils.If you are using debhelper.
 .
 Please add a dependency on ${misc:Depends} and dh&lowbar;installxfonts will
 take care of this for you.
