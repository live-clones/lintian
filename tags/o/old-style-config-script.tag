Tag: old-style-config-script
Severity: pedantic
Check: files/config-scripts
Explanation: The following file is an old style config file,
 used to retrieve information about installed libraries in the system.
 It is typically used to compile and link against one or more libraries.
 .
 Using this kind of system to pass compile file is obsolete and
 will likely introduce bugs in a multi-arch system. Particularly,
 this kind of script could only belong to a package that is not
 Multi-Arch.
 .
 You should consider to move to pkg-config file and
 warn your user to not use this script, and open a bug upstream.
 .
 You should also consider to implement this file as a compatibility
 wrapper over pkg-config.
 .
 After fixing every reverse depends of your package and use
 pkg-config reverse depends makefile, you should
 consider to put this script, as a temporary convenience of your users,
 under /usr/lib/$DEB&lowbar;HOST&lowbar;MULTIARCH/$PACKAGE/bin where
 $DEB&lowbar;HOST&lowbar;MULTIARCH is the multi-arch triplet and $PACKAGE is the
 package name. You should also consider to add a NEWS.Debian entry.
See-Also: pkg-config(1),
     http://sources.debian.net/src/imagemagick/8:6.8.9.9-6/debian/NEWS/
