Tag: duplicate-packaging-file
Severity: warning
Check: debian/filenames
Explanation: Some packaging files obtain different names when they are copied
 from source to installation packages. Debhelper sometimes adds &ast;.Debian
 extensions to NEWS, README and TODO files. That can be confusing.
 .
 Debhelper's behavior also depends on the filename.
 .
 This source package contains both a file with the proper name and also
 a file with incorrect name. Please remove the file as indicated.
 .
 Please merge all relevant information into the surviving file.
See-Also: Bug#429510, Bug#946126
