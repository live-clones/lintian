Tag: debug-symbols-not-detached
Severity: warning
Check: binaries
Renamed-From: debug-file-should-use-detached-symbols
See-Also: devref 6.7.9
Explanation: This file is in a location generally used for detached debugging
 symbols, but it appears to contain a complete copy of the executable or
 library instead of only the debugging symbols. Files in subdirectories
 of <code>/usr/lib/debug</code> mirroring the main file system should contain
 only debugging information generated by <code>objcopy
 --only-keep-debug</code>. Binaries or shared objects built with extra
 debugging should be installed directly in <code>/usr/lib/debug</code> or in
 subdirectories corresponding to the package, not in the directories that
 mirror the main file system.
 .
 If you are using dh&lowbar;strip with the --dbg-package flag, don't also install
 the library in <code>/usr/lib/debug</code>. dh&lowbar;strip does all the work for
 you.
