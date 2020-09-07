Tag: package-installs-ieee-data
Severity: error
Check: files/ieee-data
See-Also: Bug#785662
Explanation: Debian package should not install ieee oui.txt or iab.txt file
 These files are shipped in the package ieee-data and package should
 depends on the ieee-data instead of shipping these files.
 .
 Package should symlinks to /usr/share/ieee-data/iab.txt or
 /usr/share/ieee-data/oui.txt. Moreover, you should also
 depends on ieee-data package.
Renamed-From:
 package-install-ieee-data
