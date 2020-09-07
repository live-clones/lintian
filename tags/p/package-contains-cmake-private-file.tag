Tag: package-contains-cmake-private-file
Severity: error
Check: build-systems/cmake
Explanation: The package ships a file in a location reserved for <code>CMake</code>.
 It usually means you shipped a <code>Find</code> module.
 .
 Libraries should not ship Find modules Config files. Config files should
 be installed in the unversioned path
 <code>usr/(lib/&lt;arch&gt;|lib|share)/cmake/&lt;name&gt;&ast;/</code>
 .
 When CMake Config files are installed in an unversioned path, your
 package will continue to work when a new version of CMake is uploaded.
See-Also: https://wiki.debian.org/CMake, https://cmake.org/cmake/help/v3.10/manual/cmake-packages.7.html#config-file-packages
