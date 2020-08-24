Tag: library-in-root-and-usr
Severity: error
Check: usrmerge
Explanation: The package ships two files with the same name installed both in
 /lib*/ and /usr/lib*/ (or their subdirectories).
 This is not useful and is incompatible with the merged /usr directories
 scheme.
 .
 Shared library files, both static and dynamic, must be installed in
 the correct directories as documented in Policy 8.1.
See-Also: https://wiki.debian.org/UsrMerge,
     policy 8.1
