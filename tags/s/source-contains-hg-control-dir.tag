Tag: source-contains-hg-control-dir
Severity: pedantic
Check: cruft
Explanation: The upstream source contains a .hg directory. It was most likely
 included by accident since hg version control directories usually don't
 belong in releases and may contain a complete copy of the repository. If
 an upstream release tarball contains .hg directories, you should usually
 report this as a bug upstream.
