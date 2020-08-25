Tag: package-modifies-ld.so-search-path
Severity: error
Check: files/ld-so
Explanation: The package changes the search path for the runtime linker, but is
 not part of <code>libc</code>. The offending file is in
 <code>/etc/ld.so.conf.d</code>.
 .
 It is not okay to install libraries in a different directory and then
 modify the run-time link path. Shared libraries should go into
 <code>/usr/lib</code>. Alternatively, they can require binaries to set the
 <code>RPATH</code> to find the library.
 .
 Without this precaution, conflicting libraries may trigger segmentation
 faults for what should have been a conflict in the package manager.
See-Also: policy 10.2
