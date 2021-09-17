Tag: source-contains-cmake-cache-file
Severity: error
Check: build-systems/cmake
Renamed-From:
 diff-contains-cmake-cache-file
Explanation: This package ships a CMake cache file.
 .
 These files embed source paths from when they were built. They will cause
 build failures when the source is subsequently built under different paths.
 .
 They always cause errors on the buildds.
 .
 The file was probably included by accident. If it came with the upstream
 sources, please delete it before building in <code>debian/rules</code>.
