Tag: incorrect-packaging-filename
Severity: warning
Check: debian/filenames
Explanation: Some packaging files obtain different names when they are copied
 from source to installation packages. Debhelper sometimes adds &ast;.Debian
 extensions to NEWS, README and TODO files. That can be confusing.
 .
 Debhelper's behavior also depends on the filename.
 .
 This source package contains a file that debhelper will not find. The
 file will not be included in your installation packages. Important
 information, such as incompatibilties on upgrades, may not reach your
 users.
 .
 Please rename the file as indicated.
See-Also: Bug#429510, Bug#946126, Bug#946041
