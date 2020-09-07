Tag: source-contains-bzr-control-dir
Severity: pedantic
Check: cruft
Explanation: The upstream source contains a .bzr directory. It was most likely
 included by accident since bazaar-ng version control directories usually
 don't belong in releases and may contain the entire repository. When
 packaging a bzr snapshot, use bzr export to create a clean tree. If an
 upstream release tarball contains .bzr directories, you should usually
 report this as a bug upstream.
