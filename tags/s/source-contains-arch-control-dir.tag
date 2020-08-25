Tag: source-contains-arch-control-dir
Severity: pedantic
Check: cruft
Explanation: The upstream source contains an {arch} or .arch-ids directory or a
 directory starting with <code>,,</code> (used by baz for debugging traces).
 It was most likely included by accident since Arch version control
 directories usually don't belong in releases. If an upstream release
 tarball contains these directories, you should usually report this as a
 bug upstream.
