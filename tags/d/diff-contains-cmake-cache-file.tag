Tag: diff-contains-cmake-cache-file
Severity: error
Check: cruft
Explanation: The Debian diff contains a CMake cache file. These files embed the
 full path of the source tree in which they're created and cause build
 failures if they exist when the source is built under a different path,
 so they will always cause errors on the buildds. The file was probably
 accidentally included. If it is present in the upstream source, don't
 modify it in the Debian diff; instead, delete it before the build in
 <code>debian/rules</code>.
