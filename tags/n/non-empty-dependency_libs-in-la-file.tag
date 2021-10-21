Tag: non-empty-dependency_libs-in-la-file
Severity: error
Check: build-systems/libtool/la-file
Explanation: The dependency&lowbar;libs field in the .la file has not been cleared. It has
 long been a release goal to get rid of unneeded .la files and clearing the
 dependency&lowbar;libs field from the rest of them.
 .
 A non-empty dependency&lowbar;libs field will also stall the Multi-Arch
 conversion.
 .
 The .la file in itself may be useful if the library is loaded dynamically
 via libltdl.
See-Also: https://wiki.debian.org/ReleaseGoals/LAFileRemoval,
     https://lists.debian.org/debian-devel/2011/05/msg01003.html,
     https://lists.debian.org/debian-devel/2011/05/msg01146.html
